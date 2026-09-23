import Foundation

/// 資料抓取流程中可能發生的錯誤。
/// 每個 case 都提供可直接顯示給使用者的繁體中文訊息。
enum MarketDataError: LocalizedError {
    case invalidCode(String)
    case networkFailure(underlying: Error)
    case badResponse(status: Int)
    case decodingFailure(reason: String)
    case emptyDataset(code: String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidCode(let code):
            return "股票代號「\(code)」格式不正確，請輸入 4～6 碼數字或英數代號。"
        case .networkFailure(let underlying):
            return "網路連線失敗：\(underlying.localizedDescription)"
        case .badResponse(let status):
            return "伺服器回應異常（HTTP \(status)），請稍後再試。"
        case .decodingFailure(let reason):
            return "資料解析失敗：\(reason)"
        case .emptyDataset(let code):
            return "查無「\(code)」的交易資料；TWSE 與 TPEx 兩個來源皆無回應資料，系統不會產生任何模擬數據。"
        case .rateLimited:
            return "查詢過於頻繁，已被交易所端限流，請稍候數秒後再試。"
        }
    }
}
