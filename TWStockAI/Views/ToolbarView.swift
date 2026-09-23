import SwiftUI

/// 工具列：資料來源徽章與匯出動作。
struct ToolbarView: View {

    @EnvironmentObject private var state: AppState

    var body: some View {
        if let dataset = state.dataset, let analysis = state.analysis {
            HStack(spacing: 10) {
                sourceBadge(dataset: dataset)

                Text("區間 \(dataset.rangeDescription)，共 \(dataset.quotes.count) 個交易日"
                     + (dataset.institutional.isEmpty ? "" : "，法人資料 \(dataset.institutional.count) 日"))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)

                Spacer()

                actionButton("下載儀表板 PNG", symbol: "arrow.down.circle") {
                    ExportService.exportPNG(
                        view: DashboardView(dataset: dataset, analysis: analysis)
                            .padding(14)
                            .background(Theme.background),
                        suggestedName: "\(dataset.identity.code)_儀表板.png",
                        size: CGSize(width: 1600, height: 1400)
                    )
                }

                actionButton("下載 K 線圖 PNG", symbol: "arrow.down.circle") {
                    ExportService.exportPNG(
                        view: KDMAChartView(dataset: dataset, analysis: analysis)
                            .padding(14)
                            .background(Theme.background),
                        suggestedName: "\(dataset.identity.code)_KD_MA圖.png",
                        size: CGSize(width: 1600, height: 900)
                    )
                }

                actionButton("下載資料 CSV", symbol: "tablecells") {
                    ExportService.exportCSV(dataset: dataset, analysis: analysis)
                }

                actionButton("下載離線報告 HTML", symbol: "doc.richtext") {
                    ExportService.exportHTML(dataset: dataset, analysis: analysis)
                }

                actionButton("輸出 PDF", symbol: "printer") {
                    ExportService.exportPDF(
                        view: ReportView(dataset: dataset, analysis: analysis)
                            .padding(20)
                            .background(Theme.background),
                        suggestedName: "\(dataset.identity.code)_分析報告.pdf",
                        size: CGSize(width: 1240, height: 1754)
                    )
                }

                actionButton("重新整理", symbol: "arrow.clockwise") {
                    Task { await state.analyze(forceReload: true) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.background)
        }
    }

    private func sourceBadge(dataset: StockDataset) -> some View {
        HStack(spacing: 6) {
            Text("資料來源：")
                .foregroundColor(Theme.textMuted)
            Text(dataset.badge.priceSource).foregroundColor(Theme.accent)
            Text("｜").foregroundColor(Theme.textMuted)
            Text(dataset.badge.institutionalSource).foregroundColor(Theme.accent)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.accent.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(title).font(.system(size: 11))
            }
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.panelElevated)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
