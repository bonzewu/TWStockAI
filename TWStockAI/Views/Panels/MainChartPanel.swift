import SwiftUI
import Charts

/// 面板 01：主 K 線圖（K 線 + MA5/10/20/60 + 成交量 + 壓力／支撐／主力成本標註）。
struct MainChartPanel: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    private var visibleRange: Range<Int> {
        let start = max(dataset.quotes.count - 60, 0)
        return start..<dataset.quotes.count
    }

    private var points: [ChartPoint] {
        visibleRange.map { ChartPoint(id: $0, index: $0, date: dataset.quotes[$0].date, quote: dataset.quotes[$0]) }
    }

    var body: some View {
        PanelCard(index: 1, title: "主 K 線圖", subtitle: "AI 主力行為判讀系統") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    LegendItem(color: Theme.bullish, label: "K 線", isSquare: true)
                    LegendItem(color: Theme.ma5, label: "MA5")
                    LegendItem(color: Theme.ma10, label: "MA10")
                    LegendItem(color: Theme.ma20, label: "MA20")
                    LegendItem(color: Theme.ma60, label: "MA60", isDashed: true)
                    LegendItem(color: Theme.bearish, label: "成交量", isSquare: true)
                    Spacer()
                    annotationChips
                }

                priceChart.frame(height: 230)
                volumeChart.frame(height: 70)
            }
        }
    }

    /// 右上角的價位標註（壓力 / 主力成本 / 支撐）。
    private var annotationChips: some View {
        HStack(spacing: 6) {
            chip("高檔壓力區 \(Format.price(analysis.pressureZone))", tint: Theme.bullish)
            chip("主力成本 \(Format.price(analysis.mainForceCost))", tint: Theme.purple)
            chip("支撐區 \(Format.price(analysis.supportZone))", tint: Theme.accent)
        }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(tint.opacity(0.6)))
    }

    private var priceChart: some View {
        Chart {
            ForEach(points) { point in
                RectangleMark(
                    x: .value("序號", point.index),
                    yStart: .value("最低", point.quote.low),
                    yEnd: .value("最高", point.quote.high),
                    width: .fixed(1.2)
                )
                .foregroundStyle(point.quote.isBullish ? Theme.bullish : Theme.bearish)

                RectangleMark(
                    x: .value("序號", point.index),
                    yStart: .value("下緣", min(point.quote.open, point.quote.close)),
                    yEnd: .value("上緣", max(point.quote.open, point.quote.close)),
                    width: .fixed(5)
                )
                .foregroundStyle(point.quote.isBullish ? Theme.bullish : Theme.bearish)

                line(value: analysis.ma5[point.index], at: point.index, color: Theme.ma5, name: "MA5")
                line(value: analysis.ma10[point.index], at: point.index, color: Theme.ma10, name: "MA10")
                line(value: analysis.ma20[point.index], at: point.index, color: Theme.ma20, name: "MA20")
                line(value: analysis.ma60[point.index], at: point.index, color: Theme.ma60, name: "MA60", dashed: true)
            }

            // 壓力 / 支撐 / 主力成本 水平標註
            RuleMark(y: .value("壓力", analysis.pressureZone))
                .foregroundStyle(Theme.bullish.opacity(0.75))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))

            RuleMark(y: .value("主力成本", analysis.mainForceCost))
                .foregroundStyle(Theme.purple.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

            RuleMark(y: .value("支撐", analysis.supportZone))
                .foregroundStyle(Theme.accent.opacity(0.75))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }
        .chartYScale(domain: ChartSupport.priceDomain(
            quotes: visibleRange.map { dataset.quotes[$0] },
            extra: [analysis.pressureZone, analysis.supportZone, analysis.mainForceCost]
        ))
        .chartXScale(domain: (visibleRange.lowerBound - 1)...(visibleRange.upperBound + 1))
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
        .chartXAxis { indexAxis }
        .chartPlotStyle { $0.background(Theme.background.opacity(0.35)) }
    }

    /// 均線標記（抽出以維持 body 可讀性）。
    @ChartContentBuilder
    private func line(value: Double?, at index: Int, color: Color, name: String, dashed: Bool = false) -> some ChartContent {
        if let value {
            LineMark(x: .value("序號", index), y: .value(name, value), series: .value("指標", name))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: dashed ? [4, 3] : []))
        }
    }

    private var volumeChart: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("序號", point.index),
                    y: .value("成交量", point.quote.volumeLots),
                    width: .fixed(5)
                )
                .foregroundStyle((point.quote.isBullish ? Theme.bullish : Theme.bearish).opacity(0.75))
            }
        }
        .chartXScale(domain: (visibleRange.lowerBound - 1)...(visibleRange.upperBound + 1))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Theme.grid)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(Format.integer(number))
                            .font(.system(size: 8))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
        .chartXAxis { indexAxis }
        .chartPlotStyle { $0.background(Theme.background.opacity(0.35)) }
    }

    @AxisContentBuilder
    private var indexAxis: some AxisContent {
        AxisMarks(values: ChartSupport.axisIndices(count: dataset.quotes.count, stride: 10)
            .filter { visibleRange.contains($0) }) { value in
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
}
