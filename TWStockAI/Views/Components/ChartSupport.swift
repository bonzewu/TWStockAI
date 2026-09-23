import SwiftUI
import Charts

/// 圖表共用的單筆繪圖資料。
/// 以「序號」作為 X 軸可避免假日造成的空白間隙，日期僅用於座標軸標籤與提示框。
struct ChartPoint: Identifiable {
    let id: Int
    let index: Int
    let date: Date
    let quote: DailyQuote
}

/// 圖表共用工具。
enum ChartSupport {

    /// 將日 K 轉為繪圖點。
    static func points(from quotes: [DailyQuote]) -> [ChartPoint] {
        quotes.enumerated().map { ChartPoint(id: $0.offset, index: $0.offset, date: $0.element.date, quote: $0.element) }
    }

    /// 產生座標軸要顯示的序號（每 stride 筆一個刻度）。
    static func axisIndices(count: Int, stride tickStride: Int = 5) -> [Int] {
        guard count > 0 else { return [] }
        return Swift.stride(from: 0, to: count, by: max(tickStride, 1)).map { $0 }
    }

    /// 價格軸範圍（上下各留 4% 緩衝）。
    static func priceDomain(quotes: [DailyQuote], extra: [Double] = []) -> ClosedRange<Double> {
        let lows = quotes.map(\.low) + extra
        let highs = quotes.map(\.high) + extra
        guard let minimum = lows.min(), let maximum = highs.max(), maximum > minimum else {
            return 0...100
        }
        let padding = (maximum - minimum) * 0.04
        return (minimum - padding)...(maximum + padding)
    }

    /// 由序號取得日期標籤。
    static func dateLabel(points: [ChartPoint], index: Int) -> String {
        guard points.indices.contains(index) else { return "" }
        return DateFormatter.axisDate.string(from: points[index].date)
    }
}

/// 圖例項目。
struct LegendItem: View {

    let color: Color
    let label: String
    var isDashed: Bool = false
    var isSquare: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if isSquare {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 11, height: 11)
            } else {
                Capsule()
                    .fill(isDashed ? color.opacity(0.65) : color)
                    .frame(width: 16, height: 2.5)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

/// 圖表標題列（標題 + 右側動作）。
struct ChartHeader<Trailing: View>: View {

    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            trailing()
        }
    }
}

/// 圖表滑鼠追蹤覆蓋層：將游標的 X 位置換算成資料索引。
/// KD 圖與 MACD 圖共用，確保上下兩圖的十字游標同步。
struct ChartHoverOverlay: View {

    let proxy: ChartProxy
    let validRange: Range<Int>
    @Binding var hoverIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let plotOrigin = geometry[proxy.plotAreaFrame].origin
                        let xPosition = location.x - plotOrigin.x
                        guard let raw: Double = proxy.value(atX: xPosition) else {
                            hoverIndex = nil
                            return
                        }
                        let index = Int(raw.rounded())
                        hoverIndex = validRange.contains(index) ? index : nil
                    case .ended:
                        hoverIndex = nil
                    }
                }
        }
    }
}
