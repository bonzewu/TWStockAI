import SwiftUI
import Charts

/// 面板 02：AI 決策核心。
struct DecisionCorePanel: View {

    let analysis: AnalysisResult

    private var decision: DecisionCore { analysis.decision }

    var body: some View {
        PanelCard(index: 2, title: "AI 決策核心", subtitle: "AI DECISION CORE") {
            VStack(alignment: .leading, spacing: 8) {
                headline

                row(symbol: "chart.line.uptrend.xyaxis", label: "趨勢判斷", value: decision.trendJudgement, tint: Theme.warning)
                row(symbol: "link", label: "短線狀態", value: decision.shortTermState, tint: Theme.textPrimary)
                row(symbol: "person.fill", label: "主力行為", value: decision.mainForceBehavior, tint: Theme.textPrimary)
                row(symbol: "square.stack.3d.up", label: "籌碼結構", value: decision.chipStructure,
                    tint: decision.chipStructure == "轉強" ? Theme.bearish : Theme.warning)
                row(symbol: "exclamationmark.triangle", label: "隔日沖風險", value: Format.ratio(decision.nextDayRisk),
                    tint: Theme.scoreColor(100 - decision.nextDayRisk))
                row(symbol: "heart.text.square", label: "籌碼健康度",
                    value: "\(Int(decision.chipHealthScore))分 \(decision.chipHealthNote)",
                    tint: Theme.scoreColor(decision.chipHealthScore))
                row(symbol: "arrow.down.to.line", label: "支撐區間",
                    value: "\(Format.price(decision.supportLevels.primary)) / \(Format.price(decision.supportLevels.secondary))",
                    tint: Theme.bearish)
                row(symbol: "arrow.up.to.line", label: "壓力區間",
                    value: "\(Format.price(decision.resistanceLevels.primary)) / \(Format.price(decision.resistanceLevels.secondary))",
                    tint: Theme.bullish)
                row(symbol: "timer", label: "風險等級", value: decision.riskWindow, tint: Theme.textPrimary)
            }
        }
    }

    private var headline: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.warning)
            Text(decision.headline)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(Theme.warning)
            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Theme.warning.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.warning.opacity(0.5)))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func row(symbol: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundColor(Theme.textMuted)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint)
        }
    }
}

/// 面板 03：多維度判讀（六面向雷達圖）。
struct MultiDimensionPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 3, title: "多維度判讀") {
            VStack(spacing: 6) {
                Text("綜合評分：\(Int(analysis.overallScore)) / 100")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.accent)

                RadarChartView(
                    axes: analysis.radar.ordered,
                    tint: Theme.bullish,
                    centerText: analysis.grade.initial,
                    centerSubtext: "\(Int(analysis.overallScore))/100"
                )
                .frame(height: 180)

                HStack {
                    Text("總評等級：")
                        .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    Text(analysis.grade.rawValue)
                        .font(.system(size: 11, weight: .bold)).foregroundColor(Theme.warning)
                    Spacer()
                    Text("總評分數：")
                        .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    Text("\(Int(analysis.overallScore)) / 100")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(Theme.accent)
                }
            }
        }
    }
}

/// 面板 04：AI 籌碼熱區圖。
struct HeatMapPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 4, title: "AI 籌碼熱區圖") {
            HStack(alignment: .top, spacing: 10) {
                HeatMapView(cells: analysis.heatCells, priceLabels: [])
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                HeatLegendView(items: analysis.heatLegend)
                    .frame(width: 92)
            }
        }
    }
}

/// 面板 05：風險雷達圖。
struct RiskRadarPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 5, title: "風險雷達圖") {
            VStack(spacing: 6) {
                RadarChartView(axes: analysis.riskRadar, tint: Theme.warning)
                    .frame(height: 180)

                HStack {
                    Text("主力風險等級：")
                        .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    Text(analysis.mainForceRiskLevel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.scoreColor(100 - analysis.mainForceRiskIndex))
                    Spacer()
                }

                HStack {
                    Text("主力風險指數：")
                        .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    Text(Format.ratio(analysis.mainForceRiskIndex))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.scoreColor(100 - analysis.mainForceRiskIndex))
                    Spacer()
                }
            }
        }
    }
}
