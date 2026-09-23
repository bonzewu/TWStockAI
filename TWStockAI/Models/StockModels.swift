import Foundation

/// 單一交易日的日 K 資料（價量）。
/// 所有欄位皆為不可變值，方便以函式式方式串接運算。
struct DailyQuote: Identifiable, Hashable, Codable {
    let date: Date          // 交易日
    let open: Double        // 開盤價
    let high: Double        // 最高價
    let low: Double         // 最低價
    let close: Double       // 收盤價
    let change: Double      // 漲跌價差
    let volumeLots: Double  // 成交量（張）
    let turnoverCount: Int  // 成交筆數

    var id: Date { date }

    /// 當日是否為紅 K（收盤 >= 開盤）。
    var isBullish: Bool { close >= open }

    /// 當日漲跌幅（%）；以「收盤 - 漲跌價差」還原前一日收盤。
    var changePercent: Double {
        let previousClose = close - change
        guard previousClose > 0 else { return 0 }
        return change / previousClose * 100
    }
}

/// 三大法人單日買賣超（單位：張）。
struct InstitutionalFlow: Identifiable, Hashable, Codable {
    let date: Date
    let foreign: Double   // 外資（含外資自營商）
    let trust: Double     // 投信
    let dealer: Double    // 自營商

    var id: Date { date }

    /// 三大法人合計買賣超。
    var total: Double { foreign + trust + dealer }
}

/// 個股基本識別資訊。
struct StockIdentity: Hashable, Codable {
    let code: String   // 股票代號，例如 2330
    let name: String   // 股票名稱，例如 台積電
    let market: Market // 交易市場

    enum Market: String, Codable {
        case listed = "上市"    // TWSE
        case otc = "上櫃"       // TPEx / FinMind 備援
        case unknown = "未知"
    }
}

/// 資料來源標記，用於畫面上的「資料來源」徽章。
struct DataSourceBadge: Hashable {
    let priceSource: String        // 日 K 來源
    let institutionalSource: String// 法人來源
    let marginSource: String       // 融資券來源
}

/// 一次查詢所取得的完整資料集合。
struct StockDataset {
    let identity: StockIdentity
    let quotes: [DailyQuote]              // 由舊到新排序
    let institutional: [InstitutionalFlow]// 由舊到新排序
    let badge: DataSourceBadge

    /// 最新一個交易日。
    var latest: DailyQuote? { quotes.last }

    /// 資料涵蓋區間描述，例如 2026-05-04 ～ 2026-09-18。
    var rangeDescription: String {
        guard let first = quotes.first?.date, let last = quotes.last?.date else { return "—" }
        let formatter = DateFormatter.twDate
        return "\(formatter.string(from: first)) ～ \(formatter.string(from: last))"
    }
}

extension DateFormatter {
    /// yyyy-MM-dd（台北時區）。
    static let twDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// MM/dd，用於圖表座標軸。
    static let axisDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
}
