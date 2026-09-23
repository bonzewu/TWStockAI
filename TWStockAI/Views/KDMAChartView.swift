import SwiftUI
import Charts

/// 任務三：60 日 K 線 + MA5 / MA10 / MA20 與 KD 指標。
struct KDMAChartView: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    /// 滑鼠停留的資料索引。
    @State private var hoverIndex: Int?

    /// 僅顯示最近 60 個交易日，與參考設計一致。
    private var visibleRange: Range<Int> {
        let start = max(dataset.quotes.count - 60, 0)
        return start..<dataset.quotes.count
    }

    private var points: [ChartPoint] {
        visibleRange.map { index in
            ChartPoint(id: index, index: index, date: dataset.quotes[index].date, quote: dataset.quotes[index])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChartHeader(title: "60 日 K 線 + MA5 / MA10 / MA20 與 KD 指標（滑鼠移動可查看數值）") {
                Text(hoverLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
            }

            HStack(spacing: 14) {
                LegendItem(color: Theme.bullish, label: "K 線", isSquare: true)
                LegendItem(color: Theme.ma5, label: "MA5")
                LegendItem(color: Theme.ma10, label: "MA10")
                LegendItem(color: Theme.ma20, label: "MA20")
                LegendItem(color: Theme.kLine, label: "K 值")
                LegendItem(color: Theme.dLine, label: "D 值")
                Spacer()
            }

            priceChart
                .frame(height: 380)

            kdChart
                .frame(height: 200)

            Text(crossSummary)
                .font(.system(size: 11))
                .foregroundColor(Theme.textMuted)
        }
        .padding(14)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 上圖：K 線 + 均線

    private var priceChart: some View {
        Chart {
            ForEach(points) { point in
                // 影線
                RectangleMark(
                    x: .value("序號", point.index),
                    yStart: .value("最低", point.quote.low),
                    yEnd: .value("最高", point.quote.high),
                    width: .fixed(1.4)
                )
                .foregroundStyle(point.quote.isBullish ? Theme.bullish : Theme.bearish)

                // 實體
                RectangleMark(
                    x: .value("序號", point.index),
                    yStart: .value("開盤", min(point.quote.open, point.quote.close)),
                    yEnd: .value("收盤", max(point.quote.open, point.quote.close)),
                    width: .fixed(7)
                )
                .foregroundStyle(point.quote.isBullish ? Theme.bullish : Theme.bearish)
            }

            movingAverageMarks(values: analysis.ma5, color: Theme.ma5, name: "MA5")
            movingAverageMarks(values: analysis.ma10, color: Theme.ma10, name: "MA10")
            movingAverageMarks(values: analysis.ma20, color: Theme.ma20, name: "MA20")

            if let hoverIndex, points.contains(where: { $0.index == hoverIndex }) {
                RuleMark(x: .value("序號", hoverIndex))
                    .foregroundStyle(Theme.textMuted.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartYScale(domain: ChartSupport.priceDomain(quotes: visibleRange.map { dataset.quotes[$0] }))
        .chartXScale(domain: (visibleRange.lowerBound - 1)...(visibleRange.upperBound))
        .chartYAxis { styledYAxis(label: "價格 (元)") }
        .chartXAxis { styledXAxis }
        .chartPlotStyle { $0.background(Theme.background.opacity(0.4)) }
        .chartOverlay { proxy in hoverOverlay(proxy: proxy) }
        .overlay(alignment: .topLeading) { tooltip }
    }

    /// 產生均線的折線標記。
    @ChartContentBuilder
    private func movingAverageMarks(values: [Double?], color: Color, name: String) -> some ChartContent {
        ForEach(points) { point in
            if let value = values[point.index] {
                LineMark(
                    x: .value("序號", point.index),
                    y: .value(name, value),
                    series: .value("指標", name)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }
        }
    }

    // MARK: - 下圖：KD

    private var kdChart: some View {
        Chart {
            ForEach(points) { point in
                if let kd = analysis.kd[point.index] {
                    LineMark(
                        x: .value("序號", point.index),
                        y: .value("K 值", kd.k),
                        series: .value("指標", "K")
                    )
                    .foregroundStyle(Theme.kLine)

                    LineMark(
                        x: .value("序號", point.index),
                        y: .value("D 值", kd.d),
                        series: .value("指標", "D")
                    )
                    .foregroundStyle(Theme.dLine)
                }
            }

            RuleMark(y: .value("超買", 80))
                .foregroundStyle(Theme.bullish.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("超買 80").font(.system(size: 9)).foregroundColor(Theme.bullish)
                }

            RuleMark(y: .value("超賣", 20))
                .foregroundStyle(Theme.bearish.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .bottom, alignment: .trailing) {
                    Text("超賣 20").font(.system(size: 9)).foregroundColor(Theme.bearish)
                }

            if let hoverIndex, points.contains(where: { $0.index == hoverIndex }) {
                RuleMark(x: .value("序號", hoverIndex))
                    .foregroundStyle(Theme.textMuted.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: (visibleRange.lowerBound - 1)...(visibleRange.upperBound))
        .chartYAxis { styledYAxis(label: "KD") }
        .chartXAxis { styledXAxis }
        .chartPlotStyle { $0.background(Theme.background.opacity(0.4)) }
        .chartOverlay { proxy in hoverOverlay(proxy: proxy) }
    }

    // MARK: - 座標軸樣式

    @AxisContentBuilder
    private func styledYAxis(label: String) -> some AxisContent {
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
    private var styledXAxis: some AxisContent {
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

    // MARK: - 滑鼠互動

    private func hoverOverlay(proxy: ChartProxy) -> some View {
        ChartHoverOverlay(proxy: proxy, validRange: visibleRange, hoverIndex: $hoverIndex)
    }

    @ViewBuilder
    private var tooltip: some View {
        if let hoverIndex, dataset.quotes.indices.contains(hoverIndex) {
            let quote = dataset.quotes[hoverIndex]
            VStack(alignment: .leading, spacing: 3) {
                Text(DateFormatter.twDate.string(from: quote.date))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                tooltipRow("開盤", Format.price(quote.open), Theme.textSecondary)
                tooltipRow("最高", Format.price(quote.high), Theme.bullish)
                tooltipRow("最低", Format.price(quote.low), Theme.bearish)
                tooltipRow("收盤", Format.price(quote.close), Theme.changeColor(quote.change))
                tooltipRow("成交量", "\(Format.integer(quote.volumeLots)) 張", Theme.textSecondary)
                if let kd = analysis.kd[hoverIndex] {
                    tooltipRow("K / D", String(format: "%.1f / %.1f", kd.k, kd.d), Theme.accent)
                }
            }
            .padding(8)
            .background(Theme.panelElevated.opacity(0.96))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(10)
        }
    }

    private func tooltipRow(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 10)).foregroundColor(Theme.textMuted)
            Spacer(minLength: 10)
            Text(value).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(tint)
        }
        .frame(width: 130)
    }

    // MARK: - 文字摘要

    private var hoverLabel: String {
        guard let hoverIndex, dataset.quotes.indices.contains(hoverIndex) else {
            return "顯示區間：最近 \(points.count) 個交易日"
        }
        let quote = dataset.quotes[hoverIndex]
        return "\(DateFormatter.twDate.string(from: quote.date))　收盤 \(Format.price(quote.close))"
    }

    private var crossSummary: String {
        let recent = analysis.kdEvents.filter { event in
            guard let firstDate = points.first?.date else { return false }
            return event.date >= firstDate
        }
        let golden = recent.filter { $0.kind == Indicators.CrossKind.golden.rawValue }
        let death = recent.filter { $0.kind == Indicators.CrossKind.death.rawValue }
        let formatter = DateFormatter.axisDate

        return "近 60 日 KD：黃金交叉 \(golden.count) 次"
            + (golden.isEmpty ? "" : "（\(golden.suffix(3).map { formatter.string(from: $0.date) }.joined(separator: "、"))）")
            + "；死亡交叉 \(death.count) 次"
            + (death.isEmpty ? "" : "（\(death.suffix(3).map { formatter.string(from: $0.date) }.joined(separator: "、"))）")
            + "。"
    }
}
