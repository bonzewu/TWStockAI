import Foundation
import os

/// 櫃買中心（TPEx）公開資料用戶端，作為上櫃個股的備援來源。
/// 當 TWSE 查無資料時（多半代表該檔為上櫃股）自動改用本來源。
struct TPExClient {

    private let session: URLSession
    private let logger = Logger(subsystem: "com.bonzewu.TWStockAI", category: "TPExClient")

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 抓取指定月份的上櫃個股日成交資訊。
    /// TPEx 欄位順序：日期、成交仟股、成交仟元、開、高、低、收、漲跌、筆數。
    func monthlyQuotes(code: String, monthAnchor: Date) async throws -> (quotes: [DailyQuote], name: String?) {
        var request = URLRequest(url: URL(string: "https://www.tpex.org.tw/www/zh-tw/afterTrading/tradingStock")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 13_7) TWStockAI/1.0", forHTTPHeaderField: "User-Agent")

        let body = "code=\(code)&date=\(TWSEDateUtility.tpexQueryString(from: monthAnchor))&id=&response=json"
        request.httpBody = body.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MarketDataError.networkFailure(underlying: error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw MarketDataError.badResponse(status: http.statusCode)
        }

        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tables = payload["tables"] as? [[String: Any]],
              let table = tables.first else {
            logger.debug("TPEx \(code) 無法解析回應")
            return ([], nil)
        }

        let rows = table["data"] as? [[String]] ?? []
        let name = parseName(fromSubtitle: table["subtitle"] as? String, code: code)
        return (rows.compactMap(parseQuoteRow), name)
    }

    private func parseQuoteRow(_ row: [String]) -> DailyQuote? {
        guard row.count >= 8,
              let date = TWSEDateUtility.date(fromROC: row[0]),
              let volumeThousandShares = Parsing.number(row[1]),
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
            volumeLots: volumeThousandShares,       // 仟股即為張數
            turnoverCount: row.count > 8 ? Int(Parsing.number(row[8]) ?? 0) : 0
        )
    }

    /// 由 subtitle（例如「6488 環球晶 115年09月」）取出股票名稱。
    private func parseName(fromSubtitle subtitle: String?, code: String) -> String? {
        guard let subtitle else { return nil }
        let tokens = subtitle.split(separator: " ").map(String.init)
        guard let codeIndex = tokens.firstIndex(of: code), codeIndex + 1 < tokens.count else { return nil }
        return tokens[codeIndex + 1]
    }
}
