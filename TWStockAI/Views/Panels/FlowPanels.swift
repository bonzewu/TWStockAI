import SwiftUI
import Charts

/// 面板 06：累積型 AI 預測路徑圖。
struct ForecastPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 6, title: "累積型 AI 預測路徑圖", subtitle: "依近 60 日報酬統計推估") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    LegendItem(color: Theme.bullish, label: "上漲機率 \(Format.ratio(analysis.upProbability))", isSquare: true)
                    LegendItem(color: Theme.warning, label: "震盪機率 \(Format.ratio(analysis.flatProbability))", isSquare: true)
                    LegendItem(color: Theme.bearish, label: "下跌機率 \(Format.ratio(analysis.downProbability))", isSquare: true)
                    Spacer()
                }

                chart.frame(height: 150)

                HStack(spacing: 16) {
                    metric("主力方向機率", analysis.directionBias, Theme.bullish)
                    metric("強弱指標", String(format: "%+.1f%%(年化漂移)", analysis.annualizedDrift), Theme.bearish)
                    metric("相對主力成本", Format.percent(analysis.strengthVersusCost), Theme.changeColor(analysis.strengthVersusCost))
                    Spacer()
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(analysis.forecast) { point in
                AreaMark(
                    x: .value("時程", point.horizonDays),
                    yStart: .value("下緣", point.bearish),
                    yEnd: .value("上緣", point.bullish)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.bullish.opacity(0.35), Theme.bearish.opacity(0.2)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                LineMark(x: .value("時程", point.horizonDays), y: .value("樂觀", point.bullish), series: .value("路徑", "樂觀"))
                    .foregroundStyle(Theme.bullish)
                    .symbol(.circle).symbolSize(28)

                LineMark(x: .value("時程", point.horizonDays), y: .value("中位", point.neutral), series: .value("路徑", "中位"))
                    .foregroundStyle(Theme.warning)
                    .symbol(.circle).symbolSize(28)

                LineMark(x: .value("時程", point.horizonDays), y: .value("保守", point.bearish), series: .value("路徑", "保守"))
                    .foregroundStyle(Theme.bearish)
                    .symbol(.circle).symbolSize(28)
            }
        }
        .chartYScale(domain: forecastDomain)
        .chartXAxis {
            AxisMarks(values: analysis.forecast.map(\.horizonDays)) { value in
                AxisGridLine().foregroundStyle(Theme.grid)
                AxisValueLabel {
                    if let days = value.as(Int.self),
                       let point = analysis.forecast.first(where: { $0.horizonDays == days }) {
                        Text(point.horizonLabel)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Theme.grid)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(String(format: "%.0f", number))
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
        .chartPlotStyle { $0.background(Theme.background.opacity(0.35)) }
    }

    /// 預測區間的 Y 軸範圍（上下各留 3% 緩衝）。
    private var forecastDomain: ClosedRange<Double> {
        let values = analysis.forecast.flatMap { [$0.bullish, $0.neutral, $0.bearish] }
        guard let minimum = values.min(), let maximum = values.max(), maximum > minimum else {
            return 0...100
        }
        let padding = (maximum - minimum) * 0.03
        return (minimum - padding)...(maximum + padding)
    }

    private func metric(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10)).foregroundColor(Theme.textMuted)
            Text(value).font(.system(size: 12, weight: .bold)).foregroundColor(tint)
        }
    }
}

/// 面板 07：主力成本結構分布圖。
struct CostStructurePanel: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    private var bands: [CostBandPoint] { AIAnalyzer.costStructure(quotes: dataset.quotes) }

    var body: some View {
        PanelCard(index: 7, title: "主力成本結構分布圖") {
            VStack(alignment: .leading, spacing: 8) {
                // 自訂圖例，避免內建圖例文字過長而與圖表重疊
                HStack(spacing: 10) {
                    LegendItem(color: Theme.bullish, label: "主力成本區 ±2%", isSquare: true)
                    LegendItem(color: Theme.warning, label: "大量成交區 +2～5%", isSquare: true)
                    LegendItem(color: Theme.bearish, label: "套牢區 -2～-5%", isSquare: true)
                    LegendItem(color: Theme.accent, label: "衰竭區 <-5%", isSquare: true)
                    Spacer()
                }

                Chart(bands) { point in
                    AreaMark(
                        x: .value("序號", point.index),
                        y: .value("成交量", point.volume)
                    )
                    .foregroundStyle(by: .value("區間", point.band))
                }
                .chartForegroundStyleScale([
                    "衰竭區(<-5%)": Theme.accent,
                    "套牢區(-2～-5%)": Theme.bearish,
                    "主力成本區(±2%)": Theme.bullish,
                    "大量成交區(+2～5%)": Theme.warning
                ])
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: ChartSupport.axisIndices(count: dataset.quotes.count, stride: 12)) { value in
                        AxisGridLine().foregroundStyle(Theme.grid.opacity(0.4))
                        AxisValueLabel {
                            if let index = value.as(Int.self), dataset.quotes.indices.contains(index) {
                                Text(DateFormatter.axisDate.string(from: dataset.quotes[index].date))
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.textMuted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Theme.grid)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(Format.integer(number))
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.textMuted)
                            }
                        }
                    }
                }
                .chartPlotStyle { $0.background(Theme.background.opacity(0.35)) }
                .frame(height: 150)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("主力平均成本").font(.system(size: 10)).foregroundColor(Theme.textMuted)
                        HStack(spacing: 4) {
                            Text(Format.price(analysis.mainForceCost))
                                .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.accent)
                            Text("(20日VWAP)").font(.system(size: 9)).foregroundColor(Theme.textMuted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("強弱指標").font(.system(size: 10)).foregroundColor(Theme.textMuted)
                        Text(Format.percent(analysis.strengthVersusCost))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.changeColor(analysis.strengthVersusCost))
                    }
                    Spacer()
                }
            }
        }
    }
}

/// 面板 08：法人行為計量（三大法人買賣超）。
struct InstitutionalPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 8, title: "法人行為計量", subtitle: "三大法人買賣超（張）") {
            if analysis.institutionalSeries.isEmpty {
                emptyState
            } else {
                HStack(alignment: .top, spacing: 12) {
                    chart.frame(height: 150)
                    table.frame(width: 240)
                }

                HStack(spacing: 16) {
                    summary("累積買賣超",
                            analysis.cumulativeNetLots >= 0 ? "多頭" : "空頭",
                            "(\(Format.signedInteger(analysis.cumulativeNetLots)) 張)",
                            analysis.cumulativeNetLots >= 0 ? Theme.bullish : Theme.bearish)
                    Spacer()
                    summary("近5日買賣超",
                            analysis.recentFiveDayNetLots >= 0 ? "偏多" : "偏空",
                            "(\(Format.signedInteger(analysis.recentFiveDayNetLots)) 張)",
                            analysis.recentFiveDayNetLots >= 0 ? Theme.bullish : Theme.bearish)
                }
            }
        }
    }

    private var emptyState: some View {
        Text("此檔為上櫃股票或法人資料暫無提供，本面板不顯示推估值。")
            .font(.system(size: 11))
            .foregroundColor(Theme.textMuted)
            .frame(height: 150)
    }

    private var chart: some View {
        Chart {
            ForEach(analysis.institutionalSeries) { flow in
                BarMark(x: .value("日期", flow.date, unit: .day), y: .value("外資", flow.foreign))
                    .foregroundStyle(Theme.accent)
                    .position(by: .value("類別", "外資"))

                BarMark(x: .value("日期", flow.date, unit: .day), y: .value("投信", flow.trust))
                    .foregroundStyle(Theme.bullish)
                    .position(by: .value("類別", "投信"))

                BarMark(x: .value("日期", flow.date, unit: .day), y: .value("自營商", flow.dealer))
                    .foregroundStyle(Theme.bearish)
                    .position(by: .value("類別", "自營商"))

                LineMark(x: .value("日期", flow.date, unit: .day), y: .value("合計", flow.total))
                    .foregroundStyle(Theme.warning)
                    .symbol(.circle).symbolSize(24)
            }
        }
        .chartLegend(position: .top, alignment: .leading, spacing: 4)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.grid.opacity(0.4))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(DateFormatter.axisDate.string(from: date))
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Theme.grid)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(Format.integer(number))
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
        .chartPlotStyle { $0.background(Theme.background.opacity(0.35)) }
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tableCell("日期", tint: Theme.textMuted, width: 58, weight: .semibold)
                tableCell("外資", tint: Theme.textMuted, width: 46, weight: .semibold)
                tableCell("投信", tint: Theme.textMuted, width: 42, weight: .semibold)
                tableCell("自營商", tint: Theme.textMuted, width: 48, weight: .semibold)
                tableCell("合計", tint: Theme.textMuted, width: 46, weight: .semibold)
            }
            .background(Theme.panelElevated)

            ForEach(analysis.institutionalSeries.suffix(4).reversed()) { flow in
                HStack(spacing: 0) {
                    tableCell(DateFormatter.axisDate.string(from: flow.date), tint: Theme.textSecondary, width: 58)
                    tableCell(Format.signedInteger(flow.foreign), tint: Theme.changeColor(flow.foreign), width: 46)
                    tableCell(Format.signedInteger(flow.trust), tint: Theme.changeColor(flow.trust), width: 42)
                    tableCell(Format.signedInteger(flow.dealer), tint: Theme.changeColor(flow.dealer), width: 48)
                    tableCell(Format.signedInteger(flow.total), tint: Theme.changeColor(flow.total), width: 46)
                }
            }

            Text("單位：張")
                .font(.system(size: 9))
                .foregroundColor(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
        }
    }

    private func tableCell(_ text: String, tint: Color, width: CGFloat, weight: Font.Weight = .regular) -> some View {
        Text(text)
            .font(.system(size: 10, weight: weight, design: .monospaced))
            .foregroundColor(tint)
            .frame(width: width, alignment: .trailing)
            .padding(.vertical, 3)
            .padding(.horizontal, 2)
    }

    private func summary(_ title: String, _ value: String, _ detail: String, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 10)).foregroundColor(Theme.textMuted)
            Text(value).font(.system(size: 12, weight: .bold)).foregroundColor(tint)
            Text(detail).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
        }
    }
}

/// 面板 09：隔日沖風險分析。
struct DayTradeRiskPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 9, title: "隔日沖風險分析") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(analysis.dayTradeRiskMetrics) { metric in
                    MeterBar(metric: metric, tint: Theme.bullish.opacity(0.85))
                }

                Divider().overlay(Theme.grid)

                HStack {
                    Text("隔日沖風險等級：").font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    Text(analysis.dayTradeRiskLevel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.scoreColor(100 - analysis.dayTradeRiskIndex))
                    Spacer()
                    Text("風險指數：").font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    Text(Format.ratio(analysis.dayTradeRiskIndex))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.scoreColor(100 - analysis.dayTradeRiskIndex))
                }
            }
        }
    }
}
