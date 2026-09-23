import XCTest
import SwiftUI
@testable import TWStockAI

/// 版面渲染測試：以離屏渲染方式確認各分頁能完整繪製，並輸出 PNG 供人工檢視。
///
/// 需要真實資料，因此預設略過；設定 `RUN_LIVE_TESTS=1` 後執行。
/// 輸出路徑可用 `SNAPSHOT_DIR` 指定，預設為系統暫存目錄。
final class SnapshotRenderingTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_LIVE_TESTS"] == "1",
            "略過版面渲染測試；設定 RUN_LIVE_TESTS=1 可啟用。"
        )
    }

    /// 輸出目錄。
    /// App 在 Sandbox 中執行，只能寫入容器內路徑，因此預設使用容器的暫存目錄，
    /// 並在測試開始時印出實際位置方便查看產出的圖片。
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    override func setUp() {
        super.setUp()
        print("[快照輸出目錄] \(outputDirectory.path)")
    }

    /// 將視圖渲染為 PNG 並寫檔，回傳實際尺寸。
    @MainActor
    private func render<V: View>(_ view: V, size: CGSize, name: String) throws -> CGSize {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1

        let image = try XCTUnwrap(renderer.nsImage, "ImageRenderer 未能產生影像")
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))

        try data.write(to: outputDirectory.appendingPathComponent(name))
        return image.size
    }

    func test_各分頁皆能完整渲染為圖片() async throws {
        let dataset = try await MarketDataService().loadDataset(code: "2330", targetTradingDays: 98, institutionalDays: 10)
        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: dataset))

        try await MainActor.run {
            let dashboardSize = try render(
                DashboardView(dataset: dataset, analysis: analysis).padding(14).background(Theme.background),
                size: CGSize(width: 1840, height: 1460), name: "01_dashboard.png"
            )
            XCTAssertEqual(dashboardSize.width, 1840, accuracy: 1)

            _ = try render(
                KDMAChartView(dataset: dataset, analysis: analysis).padding(14).background(Theme.background),
                size: CGSize(width: 1500, height: 820), name: "02_kd_ma.png"
            )
            _ = try render(
                MACDChartView(dataset: dataset, analysis: analysis).padding(14).background(Theme.background),
                size: CGSize(width: 1500, height: 780), name: "03_macd.png"
            )
            _ = try render(
                ReportView(dataset: dataset, analysis: analysis).padding(14).background(Theme.background),
                size: CGSize(width: 1100, height: 1500), name: "04_report.png"
            )
            _ = try render(
                AlertsView(dataset: dataset, analysis: analysis).padding(14).background(Theme.background),
                size: CGSize(width: 1300, height: 700), name: "05_alerts.png"
            )
            // ScrollView 在離屏渲染下不會展開內容，因此直接渲染表格本體
            _ = try render(
                RawDataTable(
                    dataset: dataset, analysis: analysis,
                    rowIndices: Array(dataset.quotes.indices.suffix(25).reversed())
                )
                .padding(14)
                .background(Theme.background),
                size: CGSize(width: 1180, height: 420), name: "06_raw.png"
            )
        }
    }

    func test_離線HTML報告可產生且包含關鍵區塊() async throws {
        let dataset = try await MarketDataService().loadDataset(code: "2330", targetTradingDays: 60, institutionalDays: 5)
        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: dataset))
        let html = HTMLReportBuilder.build(dataset: dataset, analysis: analysis)

        ["AI 決策核心", "多維度判讀", "健康度綜合評估", "隔日沖風險分析", "主力追蹤總評判", "技術警示"]
            .forEach { section in
                XCTAssertTrue(html.contains(section), "報告缺少區塊：\(section)")
            }

        try html.write(to: outputDirectory.appendingPathComponent("07_report.html"), atomically: true, encoding: .utf8)
    }
}
