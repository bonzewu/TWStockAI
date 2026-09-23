import SwiftUI
import Charts

/// 任務四：MACD 指標圖（DIF / MACD / OSC，含黃金交叉、死亡交叉與柱狀體翻轉標記）。
struct MACDChartView: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    @State private var hoverIndex: Int?

    private var visibleRange: Range<Int> {
        let start = max(dataset.quotes.count - 60, 0)
        return start..<dataset.quotes.count
    }

    private var points: [ChartPoint] {
        visibleRange.map { index in
            ChartPoint(id: index, index: index, date: dataset.quotes[index].date, quote: dataset.quotes[index])
        }
    }

    /// 只保留顯示區間內的交叉事件，並對應回資料索引。
    private var visibleEvents: [(index: Int, event: Indicators.CrossEvent)] {
        analysis.macdEvents.compactMap { event in
            guard let index = dataset.quotes.firstIndex(where: { $0.date == event.date }),
                  visibleRange.contains(index) else { return nil }
            return (index, event)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChartHeader(title: "MACD 指標圖（DIF / MACD / OSC，含黃金交叉、死亡交叉與柱狀體翻轉標記）") {
                Text(hoverLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
            }

            HStack(spacing: 14) {
                LegendItem(color: Theme.textPrimary, label: "收盤價")
                LegendItem(color: Theme.ma20, label: "MA20", isDashed: true)
                LegendItem(color: Theme.bearish, label: "OSC 柱狀體", isSquare: true)
                LegendItem(color: Theme.difLine, label: "DIF")
                LegendItem(color: Theme.macdLine, label: "MACD (訊號線)")
                LegendItem(color: Theme.bullish, label: "黃金交叉 ▲", isSquare: true)
                LegendItem(color: Theme.bearish, label: "死亡交叉 ◆", isSquare: true)
                Spacer()
            }

            priceChart.frame(height: 300)
            macdChart.frame(height: 260)

            Text(crossSummary)
                .font(.system(size: 11))
                .foregroundColor(Theme.textMuted)
        }
        .padding(14)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 上圖：收盤價與 MA20

    private var priceChart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("序號", point.index),
                    y: .value("收盤", point.quote.close),
                    series: .value("指標", "收盤")
                )
                .foregroundStyle(Theme.textPrimary)
                .lineStyle(StrokeStyle(lineWidth: 1.6))

                if let ma20 = analysis.ma20[point.index] {
                    LineMark(
                        x: .value("序號", point.index),
                        y: .value("MA20", ma20),
                        series: .value("指標", "MA20")
                    )
                    .foregroundStyle(Theme.ma20)
                    .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
                }
            }

            // 交叉事件的垂直標記線
            ForEach(visibleEvents, id: \.event.id) { item in
                if item.event.kind == Indicators.CrossKind.golden.rawValue
                    || item.event.kind == Indicators.CrossKind.death.rawValue {
                    RuleMark(x: .value("序號", item.index))
                        .foregroundStyle(
                            (item.event.kind == Indicators.CrossKind.golden.rawValue ? Theme.bullish : Theme.bearish)
                                .opacity(0.65)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }

            if let hoverIndex, visibleRange.contains(hoverIndex) {
                RuleMark(x: .value("序號", hoverIndex))
                    .foregroundStyle(Theme.textMuted.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartYScale(domain: ChartSupport.priceDomain(quotes: visibleRange.map { dataset.quotes[$0] }))
        .chartXScale(domain: (visibleRange.lowerBound - 1)...(visibleRange.upperBound + 1))
        .chartYAxis { priceAxis }
        .chartXAxis { dateAxis }
        .chartPlotStyle { $0.background(Theme.background.opacity(0.4)) }
        .chartOverlay { proxy in
            ChartHoverOverlay(proxy: proxy, validRange: visibleRange, hoverIndex: $hoverIndex)
        }
        .overlay(alignment: .topTrailing) { tooltip }
    }

    // MARK: - 下圖：MACD

    private var macdChart: some View {
        Chart {
            ForEach(points) { point in
                if let macd = analysis.macd[point.index] {
                    // OSC 柱狀體
                    BarMark(
                        x: .value("序號", point.index),
                        y: .value("OSC", macd.osc),
                        width: .fixed(6)
                    )
                    .foregroundStyle(macd.osc >= 0 ? Theme.bullish.opacity(0.85) : Theme.bearish.opacity(0.85))

                    LineMark(
                        x: .value("序號", point.index),
                        y: .value("DIF", macd.dif),
                        series: .value("指標", "DIF")
                    )
                    .foregroundStyle(Theme.difLine)
                    .lineStyle(StrokeStyle(lineWidth: 1.6))

                    LineMark(
                        x: .value("序號", point.index),
                        y: .value("MACD", macd.macd),
                        series: .value("指標", "MACD")
                    )
                    .foregroundStyle(Theme.macdLine)
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
                }
            }

            // 交叉與翻轉事件標記
            ForEach(visibleEvents, id: \.event.id) { item in
                PointMark(
                    x: .value("序號", item.index),
                    y: .value("標記", item.event.value)
                )
                .symbol(symbol(for: item.event.kind))
                .symbolSize(item.event.kind.contains("交叉") ? 90 : 45)
                .foregroundStyle(color(for: item.event.kind))
            }

            RuleMark(y: .value("零軸", 0))
                .foregroundStyle(Theme.grid)
                .lineStyle(StrokeStyle(lineWidth: 1))

            if let hoverIndex, visibleRange.contains(hoverIndex) {
                RuleMark(x: .value("序號", hoverIndex))
                    .foregroundStyle(Theme.textMuted.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXScale(domain: (visibleRange.lowerBound - 1)...(visibleRange.upperBound + 1))
        .chartYAxis { macdAxis }
        .chartXAxis { dateAxis }
        .chartPlotStyle { $0.background(Theme.background.opacity(0.4)) }
        .chartOverlay { proxy in
            ChartHoverOverlay(proxy: proxy, validRange: visibleRange, hoverIndex: $hoverIndex)
        }
    }

    /// 依事件類型回傳符號。
    private func symbol(for kind: String) -> BasicChartSymbolShape {
        switch kind {
        case Indicators.CrossKind.golden.rawValue: return .triangle
        case Indicators.CrossKind.death.rawValue: return .diamond
        default: return .circle
        }
    }

    /// 依事件類型回傳顏色。
    private func color(for kind: String) -> Color {
        switch kind {
        case Indicators.CrossKind.golden.rawValue, Indicators.CrossKind.oscTurnPositive.rawValue:
            return Theme.bullish
        default:
            return Theme.bearish
        }
    }

    // MARK: - 座標軸

    @AxisContentBuilder
    private var priceAxis: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine().foregroundStyle(Theme.grid)
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text(String(format: "%.0f", number))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
    }

    @AxisContentBuilder
    private var macdAxis: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine().foregroundStyle(Theme.grid)
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text(String(format: "%.1f", number))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
    }

    @AxisContentBuilder
    private var dateAxis: some AxisContent {
        AxisMarks(values: ChartSupport.axisIndices(count: dataset.quotes.count, stride: 5)
            .filter { visibleRange.contains($0) }) { value in
            AxisGridLine().foregroundStyle(Theme.grid.opacity(0.5))
            AxisValueLabel {
                if let index = value.as(Int.self), dataset.quotes.indices.contains(index) {
                    Text(DateFormatter.axisDate.string(from: dataset.quotes[index].date))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
    }

    // MARK: - 提示與摘要

    @ViewBuilder
    private var tooltip: some View {
        if let hoverIndex, dataset.quotes.indices.contains(hoverIndex) {
            let quote = dataset.quotes[hoverIndex]
            VStack(alignment: .leading, spacing: 3) {
                Text(DateFormatter.twDate.string(from: quote.date))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                row("收盤", Format.price(quote.close), Theme.changeColor(quote.change))
                if let ma20 = analysis.ma20[hoverIndex] {
                    row("MA20", Format.price(ma20), Theme.ma20)
                }
                if let macd = analysis.macd[hoverIndex] {
                    row("DIF", String(format: "%.2f", macd.dif), Theme.difLine)
                    row("MACD", String(format: "%.2f", macd.macd), Theme.macdLine)
                    row("OSC", String(format: "%.2f", macd.osc), macd.osc >= 0 ? Theme.bullish : Theme.bearish)
                }
            }
            .padding(8)
            .background(Theme.panelElevated.opacity(0.96))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(10)
        }
    }

    private func row(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 10)).foregroundColor(Theme.textMuted)
            Spacer(minLength: 10)
            Text(value).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(tint)
        }
        .frame(width: 130)
    }

    private var hoverLabel: String {
        guard let hoverIndex, dataset.quotes.indices.contains(hoverIndex) else {
            return "顯示區間：最近 \(points.count) 個交易日"
        }
        return "\(DateFormatter.twDate.string(from: dataset.quotes[hoverIndex].date))"
    }

    private var crossSummary: String {
        let formatter = DateFormatter.axisDate
        let golden = visibleEvents.filter { $0.event.kind == Indicators.CrossKind.golden.rawValue }
        let death = visibleEvents.filter { $0.event.kind == Indicators.CrossKind.death.rawValue }
        let positive = visibleEvents.filter { $0.event.kind == Indicators.CrossKind.oscTurnPositive.rawValue }
        let negative = visibleEvents.filter { $0.event.kind == Indicators.CrossKind.oscTurnNegative.rawValue }

        /// 將事件日期組成括號內的說明文字。
        func dates(_ items: [(index: Int, event: Indicators.CrossEvent)]) -> String {
            items.isEmpty ? "" : "（\(items.suffix(3).map { formatter.string(from: $0.event.date) }.joined(separator: "、"))）"
        }

        return "近 60 日：黃金交叉 \(golden.count) 次\(dates(golden))；死亡交叉 \(death.count) 次\(dates(death))；"
            + "柱狀體翻正 \(positive.count) 次、翻負 \(negative.count) 次。"
    }
}
