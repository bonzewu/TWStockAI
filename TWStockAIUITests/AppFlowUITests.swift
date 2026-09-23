import XCTest

/// 端對端（E2E）測試：以實際啟動的 App 驗證主要操作流程。
/// 這些測試僅操作介面元件，不依賴外部網路是否成功回應。
final class AppFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func test_起始畫面_顯示標題與快速選擇按鈕() {
        XCTAssertTrue(app.staticTexts["台股 AI 主力行為判讀系統"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["開始分析"].exists)
        XCTAssertTrue(app.buttons["2330 台積電"].exists)
    }

    func test_輸入代號後_分析按鈕可被點擊() throws {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))

        field.click()
        field.typeText("2330")

        let analyzeButton = app.buttons["開始分析"]
        XCTAssertTrue(analyzeButton.isEnabled)
        analyzeButton.click()

        // 無論網路成敗，畫面都應離開「等待輸入」狀態：
        // 成功時出現任務分頁，失敗時出現錯誤對話框。
        let dashboardTab = app.buttons["AI 儀表板"]
        let errorDialog = app.staticTexts["查詢失敗"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in dashboardTab.exists || errorDialog.exists },
            object: nil
        )
        wait(for: [expectation], timeout: 60)
    }

    func test_查詢成功後_可切換四大任務分頁() throws {
        app.buttons["2330 台積電"].click()

        let dashboardTab = app.buttons["AI 儀表板"]
        guard dashboardTab.waitForExistence(timeout: 60) else {
            throw XCTSkip("查詢未成功（可能無網路），略過分頁切換驗證。")
        }

        ["任務一：綜合分析報告", "任務二：技術警示報告", "任務三：KD + MA 圖表",
         "任務四：MACD 圖表", "原始資料表"].forEach { title in
            let tab = app.buttons[title]
            XCTAssertTrue(tab.exists, "找不到分頁：\(title)")
            tab.click()
        }

        dashboardTab.click()
        XCTAssertTrue(app.staticTexts["AI 決策核心"].waitForExistence(timeout: 10))
    }
}
