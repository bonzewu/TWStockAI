import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 匯出服務：CSV、離線 HTML 報告、PNG 圖檔與 PDF。
/// 全部透過 NSSavePanel 由使用者指定存檔位置（符合 App Sandbox 規範）。
@MainActor
enum ExportService {

    // MARK: - 存檔面板

    /// 顯示存檔面板並執行寫入動作。
    private static func presentSavePanel(
        suggestedName: String,
        contentType: UTType,
        write: (URL) throws -> Void
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try write(url)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private static func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "匯出失敗"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "了解")
        alert.runModal()
    }

    // MARK: - CSV

    /// 匯出日 K 與指標明細為 CSV（UTF-8 with BOM，確保 Excel 正確辨識中文）。
    static func exportCSV(dataset: StockDataset, analysis: AnalysisResult) {
        let header = "日期,開盤,最高,最低,收盤,漲跌,漲跌幅(%),成交量(張),成交筆數,MA5,MA10,MA20,MA60,K值,D值,DIF,MACD,OSC"

        let rows = dataset.quotes.indices.map { index -> String in
            let quote = dataset.quotes[index]
            let kd = analysis.kd[index]
            let macd = analysis.macd[index]

            /// 將 Optional 數值轉為 CSV 欄位字串。
            func field(_ value: Double?) -> String {
                value.map { String(format: "%.2f", $0) } ?? ""
            }

            return [
                DateFormatter.twDate.string(from: quote.date),
                field(quote.open), field(quote.high), field(quote.low), field(quote.close),
                field(quote.change), field(quote.changePercent),
                String(format: "%.0f", quote.volumeLots), "\(quote.turnoverCount)",
                field(analysis.ma5[index]), field(analysis.ma10[index]),
                field(analysis.ma20[index]), field(analysis.ma60[index]),
                field(kd?.k), field(kd?.d),
                field(macd?.dif), field(macd?.macd), field(macd?.osc)
            ].joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")
        let bom = "\u{FEFF}"

        presentSavePanel(
            suggestedName: "\(dataset.identity.code)_\(dataset.identity.name)_日K明細.csv",
            contentType: .commaSeparatedText
        ) { url in
            try (bom + csv).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - 離線 HTML 報告

    /// 匯出可離線閱讀的 HTML 分析報告。
    static func exportHTML(dataset: StockDataset, analysis: AnalysisResult) {
        let html = HTMLReportBuilder.build(dataset: dataset, analysis: analysis)

        presentSavePanel(
            suggestedName: "\(dataset.identity.code)_\(dataset.identity.name)_AI分析報告.html",
            contentType: .html
        ) { url in
            try html.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - PNG

    /// 將任一 SwiftUI 視圖渲染成 PNG 檔。
    static func exportPNG<V: View>(view: V, suggestedName: String, size: CGSize) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2

        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            presentError("無法產生 PNG 影像。")
            return
        }

        presentSavePanel(suggestedName: suggestedName, contentType: .png) { url in
            try data.write(to: url)
        }
    }

    // MARK: - PDF

    /// 將任一 SwiftUI 視圖輸出為單頁 PDF。
    static func exportPDF<V: View>(view: V, suggestedName: String, size: CGSize) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))

        presentSavePanel(suggestedName: suggestedName, contentType: .pdf) { url in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                throw MarketDataError.decodingFailure(reason: "無法建立 PDF 繪圖環境")
            }

            renderer.render { _, renderView in
                context.beginPDFPage(nil)
                renderView(context)
                context.endPDFPage()
                context.closePDF()
            }
        }
    }
}
