import SwiftUI

/// 任務二：技術警示報告。
struct AlertsView: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    /// 目前選取的嚴重度篩選（nil 表示全部）。
    @State private var severityFilter: TechnicalAlert.Severity?

    private var filtered: [TechnicalAlert] {
        guard let severityFilter else { return analysis.alerts }
        return analysis.alerts.filter { $0.severity == severityFilter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statistics
            list
        }
        .padding(14)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack {
            Text("技術警示報告（近 20 個交易日）")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            HStack(spacing: 6) {
                filterChip(nil, label: "全部")
                filterChip(.high, label: "高")
                filterChip(.medium, label: "中")
                filterChip(.low, label: "低")
            }
        }
    }

    private func filterChip(_ severity: TechnicalAlert.Severity?, label: String) -> some View {
        Button {
            severityFilter = severity
        } label: {
            Text(label)
                .font(.system(size: 11, weight: severityFilter == severity ? .bold : .regular))
                .foregroundColor(severityFilter == severity ? Theme.accent : Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(severityFilter == severity ? Theme.accent.opacity(0.15) : Theme.panelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private var statistics: some View {
        HStack(spacing: 10) {
            statCard("高風險警示", analysis.alerts.filter { $0.severity == .high }.count, Theme.bullish)
            statCard("中度提醒", analysis.alerts.filter { $0.severity == .medium }.count, Theme.warning)
            statCard("低度訊息", analysis.alerts.filter { $0.severity == .low }.count, Theme.bearish)
            statCard("警示總數", analysis.alerts.count, Theme.accent)
            Spacer()
        }
    }

    private func statCard(_ title: String, _ count: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundColor(Theme.textMuted)
            Text("\(count) 則").font(.system(size: 18, weight: .bold)).foregroundColor(tint)
        }
        .frame(width: 110, alignment: .leading)
        .padding(10)
        .background(Theme.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var list: some View {
        if filtered.isEmpty {
            Text("目前條件下沒有任何技術警示。")
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        } else {
            VStack(spacing: 0) {
                ForEach(filtered) { alert in
                    HStack(alignment: .top, spacing: 10) {
                        Text(DateFormatter.twDate.string(from: alert.date))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 92, alignment: .leading)

                        Text(alert.severity.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(severityColor(alert.severity))
                            .frame(width: 26)
                            .padding(.vertical, 2)
                            .background(severityColor(alert.severity).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text(alert.category)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .frame(width: 48, alignment: .leading)

                        Text(alert.message)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 8)
                    .background(Theme.panelElevated.opacity(0.4))

                    Divider().overlay(Theme.grid)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func severityColor(_ severity: TechnicalAlert.Severity) -> Color {
        switch severity {
        case .high: return Theme.bullish
        case .medium: return Theme.warning
        case .low: return Theme.bearish
        }
    }
}
