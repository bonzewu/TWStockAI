import Foundation
import os

/// 市場資料聚合服務。
///
/// 抓取策略：
/// 1. 日 K：TWSE 優先，逐月往回抓到滿足目標交易日數；查無資料時改用 TPEx（上櫃）。
/// 2. 三大法人：以日 K 的最後 N 個交易日為基準逐日查詢 TWSE T86。
/// 3. 兩個來源皆失敗時直接丟出錯誤，絕不產生任何模擬數據。
actor MarketDataService {

    private let twse: TWSEClient
    private let tpex: TPExClient
    private let logger = Logger(subsystem: "com.bonzewu.TWStockAI", category: "MarketDataService")

    /// 以代號為 key 的記憶體快取，避免短時間重複查詢造成交易所端限流。
    private var cache: [String: (dataset: StockDataset, timestamp: Date)] = [:]
    private let cacheLifetime: TimeInterval = 120

    init(twse: TWSEClient = TWSEClient(), tpex: TPExClient = TPExClient()) {
        self.twse = twse
        self.tpex = tpex
    }

    /// 查詢單一個股的完整資料集。
    /// - Parameters:
    ///   - code: 股票代號
    ///   - targetTradingDays: 目標交易日數（預設 98 日，對應參考設計的資料筆數）
    ///   - institutionalDays: 三大法人回溯天數
    func loadDataset(
        code rawCode: String,
        targetTradingDays: Int = 98,
        institutionalDays: Int = 12
    ) async throws -> StockDataset {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 4, code.count <= 6, code.rangeOfCharacter(from: .alphanumerics) != nil else {
            throw MarketDataError.invalidCode(rawCode)
        }

        if let cached = cache[code], Date().timeIntervalSince(cached.timestamp) < cacheLifetime {
            logger.debug("使用快取資料：\(code)")
            return cached.dataset
        }

        // 一個月約 20 個交易日，多抓一個月作為緩衝
        let monthCount = max(2, Int(ceil(Double(targetTradingDays) / 20.0)) + 1)
        let anchors = TWSEDateUtility.recentMonthAnchors(count: monthCount)

        let listedResult = try await collectQuotes(code: code, anchors: anchors, useTPEx: false)
        let (quotes, name, market): ([DailyQuote], String?, StockIdentity.Market) = try await {
            if listedResult.quotes.isEmpty {
                logger.info("TWSE 查無 \(code)，改用 TPEx 備援")
                let otcResult = try await collectQuotes(code: code, anchors: anchors, useTPEx: true)
                return (otcResult.quotes, otcResult.name, .otc)
            }
            return (listedResult.quotes, listedResult.name, .listed)
        }()

        guard !quotes.isEmpty else { throw MarketDataError.emptyDataset(code: code) }

        let trimmed = Array(quotes.suffix(targetTradingDays))
        let institutional = market == .listed
            ? await collectInstitutional(code: code, quotes: trimmed, days: institutionalDays)
            : []

        let dataset = StockDataset(
            identity: StockIdentity(code: code, name: name ?? code, market: market),
            quotes: trimmed,
            institutional: institutional,
            badge: DataSourceBadge(
                priceSource: market == .listed ? "日K TWSE" : "日K TPEx",
                institutionalSource: institutional.isEmpty ? "法人 無資料" : "法人 TWSE",
                marginSource: market == .listed ? "融資券 TWSE" : "融資券 TPEx"
            )
        )

        cache[code] = (dataset, Date())
        return dataset
    }

    /// 清除快取，供「重新整理」使用。
    func invalidateCache(code: String? = nil) {
        if let code {
            cache.removeValue(forKey: code.uppercased())
        } else {
            cache.removeAll()
        }
    }

    // MARK: - 內部流程

    /// 逐月抓取日 K，並依日期排序去重。
    private func collectQuotes(
        code: String,
        anchors: [Date],
        useTPEx: Bool
    ) async throws -> (quotes: [DailyQuote], name: String?) {

        // 逐月序列請求並在每次之間稍作間隔，避免交易所端限流
        let collected = try await anchors.asyncReduce(into: ([DailyQuote](), String?.none)) { accumulated, anchor in
            let result = useTPEx
                ? try await tpex.monthlyQuotes(code: code, monthAnchor: anchor)
                : try await twse.monthlyQuotes(code: code, monthAnchor: anchor)

            accumulated.0.append(contentsOf: result.quotes)
            accumulated.1 = accumulated.1 ?? result.name
            try? await Task.sleep(nanoseconds: 180_000_000)   // 0.18 秒
        }

        // 以日期去重後由舊到新排序
        let unique = Dictionary(collected.0.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        return (unique.values.sorted { $0.date < $1.date }, collected.1)
    }

    /// 依日 K 的最後 N 個交易日抓取三大法人資料。
    /// 單日查詢失敗時略過該日，不影響整體結果。
    private func collectInstitutional(code: String, quotes: [DailyQuote], days: Int) async -> [InstitutionalFlow] {
        let targetDates = quotes.suffix(days).map(\.date)

        let flows = await targetDates.asyncReduce(into: [InstitutionalFlow]()) { accumulated, date in
            if let flow = try? await twse.institutionalFlow(code: code, date: date) {
                accumulated.append(flow)
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        return flows.sorted { $0.date < $1.date }
    }
}

// MARK: - 非同步序列化工具

extension Sequence {
    /// 非同步版本的 reduce(into:)，保證依序執行，用於需要限流的網路請求。
    func asyncReduce<Result>(
        into initial: Result,
        _ body: (inout Result, Element) async throws -> Void
    ) async rethrows -> Result {
        var result = initial
        for element in self {
            try await body(&result, element)
        }
        return result
    }
}
