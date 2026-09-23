import Foundation
import os

/// 證交所（TWSE）公開資料用戶端，負責上市個股的日 K 與三大法人資料。
/// 所有解析皆為容錯式：欄位缺漏或格式異常時略過該筆，而非讓整次查詢失敗。
struct TWSEClient {

    private let session: URLSession
    private let logger = Logger(subsystem: "com.bonzewu.TWStockAI", category: "TWSEClient")

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - 日 K

    /// 抓取指定月份的個股日成交資訊。
    /// - Returns: 該月份的日 K 陣列與個股名稱；若該月無資料則回傳空陣列。
    func monthlyQuotes(code: String, monthAnchor: Date) async throws -> (quotes: [DailyQuote], name: String?) {
        let dateString = TWSEDateUtility.queryString(from: monthAnchor)
        var components = URLComponents(string: "https://www.twse.com.tw/rwd/zh/afterTrading/STOCK_DAY")!
        components.queryItems = [
            URLQueryItem(name: "date", value: dateString),
            URLQueryItem(name: "stockNo", value: code),
            URLQueryItem(name: "response", value: "json")
        ]

        let payload = try await fetchJSON(url: components.url!)

        // stat 非 OK 代表該月無資料（例如尚未開市的月份），視為空結果而非錯誤
        guard let stat = payload["stat"] as? String, stat == "OK" else {
            logger.debug("TWSE \(code) \(dateString) 無資料：\(String(describing: payload["stat"]))")
            return ([], nil)
        }

        let rows = payload["data"] as? [[String]] ?? []
        let name = parseName(fromTitle: payload["title"] as? String, code: code)
        let quotes = rows.compactMap(parseQuoteRow)
        return (quotes, name)
    }

    /// 將 TWSE 單列資料轉為 DailyQuote。
    /// 欄位順序：日期、成交股數、成交金額、開、高、低、收、漲跌價差、成交筆數、註記
    private func parseQuoteRow(_ row: [String]) -> DailyQuote? {
        guard row.count >= 9,
              let date = TWSEDateUtility.date(fromROC: row[0]),
              let shares = Parsing.number(row[1]),
              let open = Parsing.number(row[3]),
              let high = Parsing.number(row[4]),
              let low = Parsing.number(row[5]),
              let close = Parsing.number(row[6]) else { return nil }

        return DailyQuote(
            date: date,
            open: open,
            high: high,
            low: low,
            close: close,
            change: Parsing.signedNumber(row[7]) ?? 0,
            volumeLots: shares / 1_000,             // 股 → 張
            turnoverCount: Int(Parsing.number(row[8]) ?? 0)
        )
    }

    /// 由 title（例如「115年09月 2330 台積電 各日成交資訊」）取出股票名稱。
    private func parseName(fromTitle title: String?, code: String) -> String? {
        guard let title, let range = title.range(of: code) else { return nil }
        let tail = title[range.upperBound...]
            .replacingOccurrences(of: "各日成交資訊", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return tail.isEmpty ? nil : tail
    }

    // MARK: - 三大法人

    /// 抓取指定日期的三大法人買賣超（全市場），並過濾出指定個股。
    /// 若當日非交易日則回傳 nil。
    func institutionalFlow(code: String, date: Date) async throws -> InstitutionalFlow? {
        var components = URLComponents(string: "https://www.twse.com.tw/rwd/zh/fund/T86")!
        components.queryItems = [
            URLQueryItem(name: "date", value: TWSEDateUtility.queryString(from: date)),
            URLQueryItem(name: "selectType", value: "ALL"),
            URLQueryItem(name: "response", value: "json")
        ]

        let payload = try await fetchJSON(url: components.url!)
        guard let stat = payload["stat"] as? String, stat == "OK",
              let fields = payload["fields"] as? [String],
              let rows = payload["data"] as? [[String]] else { return nil }

        // 以欄位名稱定位索引，避免交易所調整欄位順序時解析錯位
        let foreignIndex = fields.firstIndex(of: "外陸資買賣超股數(不含外資自營商)")
        let foreignDealerIndex = fields.firstIndex(of: "外資自營商買賣超股數")
        let trustIndex = fields.firstIndex(of: "投信買賣超股數")
        let dealerIndex = fields.firstIndex(of: "自營商買賣超股數")

        guard let target = rows.first(where: { $0.first?.trimmingCharacters(in: .whitespaces) == code }) else {
            return nil
        }

        /// 以索引安全取值，並由股換算為張。
        func lots(_ index: Int?) -> Double {
            guard let index, index < target.count else { return 0 }
            return (Parsing.signedNumber(target[index]) ?? 0) / 1_000
        }

        return InstitutionalFlow(
            date: date,
            foreign: lots(foreignIndex) + lots(foreignDealerIndex),
            trust: lots(trustIndex),
            dealer: lots(dealerIndex)
        )
    }

    // MARK: - 共用請求

    /// 送出請求並解析為 JSON 字典。
    private func fetchJSON(url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 13_7) TWStockAI/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MarketDataError.networkFailure(underlying: error)
        }

        if let http = response as? HTTPURLResponse {
            guard (200..<300).contains(http.statusCode) else {
                throw http.statusCode == 429 ? MarketDataError.rateLimited : MarketDataError.badResponse(status: http.statusCode)
            }
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MarketDataError.decodingFailure(reason: "TWSE 回應非預期的 JSON 格式")
        }
        return object
    }
}

/// 數值字串解析工具。
enum Parsing {

    /// 解析帶千分位的數值字串；"--"、"X"、空字串等皆回傳 nil。
    static func number(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// 解析可能帶有 + / - / X 前綴的漲跌欄位。
    static func signedNumber(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "X", with: "")
            .replacingOccurrences(of: "＋", with: "+")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != "--" else { return nil }
        return Double(cleaned)
    }
}
