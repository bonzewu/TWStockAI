import SwiftUI

/// 籌碼熱區圖：時間（X）× 價格（Y）的成交量密度矩陣。
struct HeatMapView: View {

    let cells: [HeatCell]
    let priceLabels: [Double]

    var body: some View {
        GeometryReader { proxy in
            let columns = (cells.map(\.columnIndex).max() ?? 0) + 1
            let buckets = (cells.map(\.priceBucket).max() ?? 0) + 1
            let cellWidth = proxy.size.width / Double(max(columns, 1))
            let cellHeight = proxy.size.height / Double(max(buckets, 1))

            Canvas { context, _ in
                cells.forEach { cell in
                    // Y 軸需反轉：價格高的區間畫在上方
                    let rect = CGRect(
                        x: Double(cell.columnIndex) * cellWidth,
                        y: proxy.size.height - Double(cell.priceBucket + 1) * cellHeight,
                        width: cellWidth - 1,
                        height: cellHeight - 1
                    )
                    // 以平方根縮放提升低密度區的對比，避免整片深藍難以辨識
                    let scaled = sqrt(max(cell.intensity, 0))
                    context.fill(Path(rect), with: .color(Theme.heatColor(scaled)))
                }
            }
        }
    }
}

/// 熱區圖例（壓力區 / 大量成交區 / …）。
struct HeatLegendView: View {

    let items: [HeatLegendItem]

    private let palette: [Color] = [
        Color(hex: 0xEF4444), Color(hex: 0xFACC15), Color(hex: 0x22C55E),
        Color(hex: 0x0EA5E9), Color(hex: 0x1D4ED8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(palette[index % palette.count])
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.label)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                        Text(Format.ratio(item.percentage))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(palette[index % palette.count])
                    }
                }
            }
        }
    }
}
