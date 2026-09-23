import Foundation

/// 交易所日期工具：處理民國年字串與台北時區行事曆。
enum TWSEDateUtility {

    /// 台北時區行事曆。
    static let taipeiCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei") ?? .current
        return calendar
    }()

    /// 將民國年字串（115/09/01 或 115年09月01日）轉為 Date。
    static func date(fromROC text: String) -> Date? {
        let digits = text
            .replacingOccurrences(of: "年", with: "/")
            .replacingOccurrences(of: "月", with: "/")
            .replacingOccurrences(of: "日", with: "")
            .split(separator: "/")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        guard digits.count == 3 else { return nil }
        var components = DateComponents()
        components.year = digits[0] + 1911   // 民國轉西元
        components.month = digits[1]
        components.day = digits[2]
        return taipeiCalendar.date(from: components)
    }

    /// 產生查詢用的 yyyyMMdd 字串。
    static func queryString(from date: Date) -> String {
        let components = taipeiCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// 產生 TPEx 查詢用的 yyyy/MM/dd 字串。
    static func tpexQueryString(from date: Date) -> String {
        let components = taipeiCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d/%02d/%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// 回傳最近 n 個月的「每月第一天」（由舊到新），用於逐月抓取日 K。
    static func recentMonthAnchors(count: Int, from reference: Date = Date()) -> [Date] {
        let startOfMonth = taipeiCalendar.date(
            from: taipeiCalendar.dateComponents([.year, .month], from: reference)
        ) ?? reference

        return (0..<count)
            .compactMap { taipeiCalendar.date(byAdding: .month, value: -$0, to: startOfMonth) }
            .reversed()
    }
}
