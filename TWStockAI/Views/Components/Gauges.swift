import SwiftUI
import Foundation

/// 甜甜圈進度環：對應參考設計的健康度／買賣力分布。
struct DonutGauge: View {

    let value: Double           // 0～100
    let label: String
    let tint: Color
    var diameter: CGFloat = 78
    var lineWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Theme.grid, lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: min(max(value / 100, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(Format.ratio(value))
                    .font(.system(size: diameter * 0.24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(width: diameter, height: diameter)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

/// 水平量測條：對應參考設計的隔日沖風險分析與 AI 信心維度。
struct MeterBar: View {

    let metric: Metric
    var tint: Color = Theme.accent
    var showsValue: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            Text(metric.label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 92, alignment: .leading)
                .lineLimit(2)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.grid)
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * min(max(metric.value / 100, 0), 1))
                }
            }
            .frame(height: 8)

            if showsValue {
                Text(Format.ratio(metric.value))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
    }
}

/// 半圓儀表：對應參考設計的台股市場情緒儀表板。
struct SemiCircleGauge: View {

    let value: Double           // 0～100
    let caption: String
    let valueLabel: String

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, size in
                let radius = min(size.width / 2, size.height) - 10
                let center = CGPoint(x: size.width / 2, y: size.height - 6)

                // 背景三色弧（紅 / 黃 / 綠）
                let segments: [(start: Double, end: Double, color: Color)] = [
                    (180, 240, Theme.bullish),
                    (240, 300, Theme.warning),
                    (300, 360, Theme.bearish)
                ]

                segments.forEach { segment in
                    var path = Path()
                    path.addArc(
                        center: center, radius: radius,
                        startAngle: .degrees(segment.start), endAngle: .degrees(segment.end),
                        clockwise: false
                    )
                    context.stroke(path, with: .color(segment.color.opacity(0.85)), style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                }

                // 指針
                let radians = Angle.degrees(180 + min(max(value, 0), 100) * 1.8).radians
                let needleLength = Double(radius) - 4
                let needle = CGPoint(
                    x: Double(center.x) + Foundation.cos(radians) * needleLength,
                    y: Double(center.y) + Foundation.sin(radians) * needleLength
                )
                var needlePath = Path()
                needlePath.move(to: center)
                needlePath.addLine(to: needle)
                context.stroke(needlePath, with: .color(Theme.textPrimary), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                    with: .color(Theme.textPrimary)
                )
            }
            .frame(height: 72)

            HStack(spacing: 6) {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                Text(valueLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.scoreColor(value))
            }
        }
    }
}

/// 紅黃綠號誌燈。
struct TrafficLightView: View {

    let light: SignalLight

    var body: some View {
        VStack(spacing: 6) {
            lamp(color: Theme.bullish, isOn: light == .red)
            lamp(color: Theme.warning, isOn: light == .yellow)
            lamp(color: Theme.bearish, isOn: light == .green)
        }
        .padding(8)
        .background(Theme.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func lamp(color: Color, isOn: Bool) -> some View {
        Circle()
            .fill(isOn ? color : color.opacity(0.18))
            .frame(width: 22, height: 22)
            .shadow(color: isOn ? color.opacity(0.7) : .clear, radius: 6)
    }
}
