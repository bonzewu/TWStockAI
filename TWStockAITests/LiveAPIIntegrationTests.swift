import XCTest
@testable import TWStockAI

/// 對外部 API 的整合測試。
///
/// 這組測試會實際連線證交所，因此預設略過；
/// 需要驗證線上資料時，設定環境變數 `RUN_LIVE_TESTS=1` 再執行。
final class LiveAPIIntegrationTests: XCTestCase {

    /// 未開啟旗標時略過整組測試，避免 CI 因外部服務不穩而失敗。
    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_LIVE_TESTS"] == "1",
            "略過線上整合測試；設定 RUN_LIVE_TESTS=1 可啟用。"
        )
    }

    func test_實際查詢台積電_可取得資料並完成分析() async throws {
        let service = MarketDataService()
        let dataset = try await service.loadDataset(code: "2330", targetTradingDays: 40, institutionalDays: 3)

        XCTAssertGreaterThan(dataset.quotes.count, 20)
        XCTAssertEqual(dataset.identity.market, .listed)
        XCTAssertTrue(dataset.identity.name.contains("台積電"))

        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: dataset))
        XCTAssertGreaterThan(analysis.mainForceCost, 0)
        XCTAssertTrue((0...100).contains(analysis.overallScore))
    }

    func test_實際查詢上櫃股_自動改用TPEx() async throws {
        let service = MarketDataService()
        let dataset = try await service.loadDataset(code: "6488", targetTradingDays: 30, institutionalDays: 2)

        XCTAssertEqual(dataset.identity.market, .otc)
        XCTAssertGreaterThan(dataset.quotes.count, 20)
    }
}
