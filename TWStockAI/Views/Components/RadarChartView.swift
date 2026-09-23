import SwiftUI

/// 多邊形雷達圖，用於「多維度判讀」與「風險雷達圖」兩個面板。
struct RadarChartView: View {

    let axes: [(label: String, value: Double)]   // 每軸 0～100
    let tint: Color
    var centerText: String?
    var centerSubtext: String?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2 - 26
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Canvas { context, _ in
                    guard axes.count >= 3 else { return }

                    // 同心網格（4 圈）
                    (1...4).forEach { ring in
                        let ringRadius = radius * Double(ring) / 4
                        context.stroke(
                            polygonPath(center: center, radius: ringRadius, count: axes.count),
                            with: .color(Theme.grid),
                            lineWidth: 1
                        )
                    }

                    // 放射軸線
                    axes.indices.forEach { index in
                        var path = Path()
                        path.move(to: center)
                        path.addLine(to: point(center: center, radius: radius, index: index, count: axes.count))
                        context.stroke(path, with: .color(Theme.grid), lineWidth: 1)
                    }

                    // 數據多邊形
                    let dataPath = valuePath(center: center, radius: radius)
                    context.fill(dataPath, with: .color(tint.opacity(0.35)))
                    context.stroke(dataPath, with: .color(tint), lineWidth: 2)

                    // 端點
                    axes.indices.forEach { index in
                        let ratio = min(max(axes[index].value / 100, 0), 1)
                        let position = point(center: center, radius: radius * ratio, index: index, count: axes.count)
                        context.fill(
                            Path(ellipseIn: CGRect(x: position.x - 3, y: position.y - 3, width: 6, height: 6)),
                            with: .color(tint)
                        )
                    }
                }

                // 軸標籤
                ForEach(axes.indices, id: \.self) { index in
                    let position = point(center: center, radius: radius + 18, index: index, count: axes.count)
                    Text(axes[index].label)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                        .position(position)
                }

                // 中央文字（綜合等級）
                if let centerText {
                    VStack(spacing: 0) {
                        Text(centerText)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(tint)
                        if let centerSubtext {
                            Text(centerSubtext)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                        }
                    }
                    .position(center)
                }
            }
        }
    }

    // MARK: - 幾何計算

    /// 計算第 index 個頂點座標（自正上方順時針排列）。
    private func point(center: CGPoint, radius: Double, index: Int, count: Int) -> CGPoint {
        let angle = -Double.pi / 2 + Double(index) * 2 * .pi / Double(count)
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    private func polygonPath(center: CGPoint, radius: Double, count: Int) -> Path {
        var path = Path()
        (0..<count).forEach { index in
            let position = point(center: center, radius: radius, index: index, count: count)
            index == 0 ? path.move(to: position) : path.addLine(to: position)
        }
        path.closeSubpath()
        return path
    }

    private func valuePath(center: CGPoint, radius: Double) -> Path {
        var path = Path()
        axes.indices.forEach { index in
            let ratio = min(max(axes[index].value / 100, 0), 1)
            let position = point(center: center, radius: radius * ratio, index: index, count: axes.count)
            index == 0 ? path.move(to: position) : path.addLine(to: position)
        }
        path.closeSubpath()
        return path
    }
}
