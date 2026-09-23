import SwiftUI
import Charts

/// 面板 10：AI 多空能量條。
struct EnergyPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 10, title: "AI 多空能量條") {
            VStack(alignment: .leading, spacing: 10) {
                MeterBar(metric: Metric("多方能量", analysis.bullEnergy), tint: Theme.bullish)
                MeterBar(metric: Metric("空方能量", analysis.bearEnergy), tint: Theme.bearish)

                HStack(spacing: 6) {
                    Text("多空比：").font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    Text(String(format: "%.2f 倍%@", analysis.bullBearRatio, analysis.bullBearRatio >= 1 ? "多" : "空"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(analysis.bullBearRatio >= 1 ? Theme.bullish : Theme.bearish)
                }

                Text("（20 日紅K量／黑K量）")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textMuted)
            }
        }
    }
}

/// 面板 11：健康度綜合評估表。
struct HealthPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 11, title: "健康度綜合評估表") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(analysis.healthMetrics) { metric in
                        DonutGauge(
                            value: metric.value,
                            label: metric.label,
                            tint: metric.label == "波動風險度"
                                ? Theme.scoreColor(100 - metric.drawableValue)
                                : Theme.scoreColor(metric.drawableValue),
                            diameter: 62,
                            lineWidth: 6
                        )
                    }
                }

                HStack(spacing: 6) {
                    Text("總評：").font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    Text(analysis.healthSummary)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.scoreColor(analysis.healthAverage))
                    Text("（\(analysis.healthMetrics.filter(\.isAvailable).count) 項平均 \(Int(analysis.healthAverage)) 分）")
                        .font(.system(size: 10)).foregroundColor(Theme.textMuted)
                }
            }
        }
    }
}

/// 面板 12：AI 主力動態信號判斷。
struct SignalPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 12, title: "AI 主力動態信號判斷") {
            HStack(alignment: .top, spacing: 12) {
                TrafficLightView(light: analysis.signalLight)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(analysis.signalRows, id: \.label) { row in
                        HStack(spacing: 6) {
                            Text("\(row.label)：")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textMuted)
                            Text(row.value)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(tint(for: row.value))
                            Spacer()
                        }
                    }

                    Text("目前燈號：\(analysis.signalLight.rawValue)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(lightColor)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var lightColor: Color {
        switch analysis.signalLight {
        case .green: return Theme.bearish
        case .yellow: return Theme.warning
        case .red: return Theme.bullish
        }
    }

    /// 依文字語意套用顏色。
    private func tint(for value: String) -> Color {
        if value.contains("轉強") || value.contains("偏多") || value.contains("偏低") || value.contains("綠燈") {
            return Theme.bearish
        }
        if value.contains("轉弱") || value.contains("偏空") || value.contains("偏高") || value.contains("紅燈") {
            return Theme.bullish
        }
        return Theme.warning
    }
}

/// 面板 13：台股市場情緒儀表板。
struct SentimentPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 13, title: "台股市場情緒儀表板") {
            HStack(alignment: .center, spacing: 10) {
                SemiCircleGauge(
                    value: analysis.marketSentiment,
                    caption: "市場情緒：",
                    valueLabel: sentimentLabel(analysis.marketSentiment)
                )
                .frame(width: 140)

                VStack(alignment: .leading, spacing: 6) {
                    sentimentRow("散戶情緒", analysis.retailSentiment)
                    sentimentRow("法人情緒", analysis.institutionalSentiment)
                    sentimentRow("主力情緒", analysis.mainForceSentiment)
                }
            }
        }
    }

    private func sentimentRow(_ label: String, _ value: Double?) -> some View {
        HStack(spacing: 6) {
            Text("\(label)：").font(.system(size: 11)).foregroundColor(Theme.textMuted)
            Text(value.map { Format.ratio($0) } ?? "無資料")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(value.map { Theme.scoreColor($0) } ?? Theme.textMuted)
            Spacer()
        }
    }

    private func sentimentLabel(_ value: Double) -> String {
        switch value {
        case 70...: return "樂觀"
        case 55..<70: return "偏多"
        case 45..<55: return "中性"
        case 30..<45: return "偏空"
        default: return "悲觀"
        }
    }
}

/// 面板 14：AI 信心維度。
struct ConfidencePanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 14, title: "AI 信心維度") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(analysis.confidenceMetrics) { metric in
                    MeterBar(metric: metric, tint: Theme.accent)
                }
            }
        }
    }
}

/// 面板 15：籌碼異動摘要。
struct ChipChangePanel: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    /// 近期法人累積淨額走勢。
    private var cumulativeSeries: [(index: Int, date: Date, value: Double)] {
        analysis.institutionalSeries.enumerated().reduce(into: [(Int, Date, Double)]()) { accumulated, item in
            let previous = accumulated.last?.2 ?? 0
            accumulated.append((item.offset, item.element.date, previous + item.element.total))
        }
    }

    private var latest: InstitutionalFlow? { analysis.institutionalSeries.last }

    var body: some View {
        PanelCard(index: 15, title: "籌碼異動摘要") {
            if let latest {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        chipRow("外資", latest.foreign)
                        chipRow("投信", latest.trust)
                        chipRow("自營商", latest.dealer)
                        chipRow("三大法人", latest.total)

                        Text(DateFormatter.twDate.string(from: latest.date))
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textMuted)
                    }

                    Chart(cumulativeSeries, id: \.index) { item in
                        LineMark(x: .value("序號", item.index), y: .value("累積", item.value))
                            .foregroundStyle(Theme.accent)
                        AreaMark(x: .value("序號", item.index), y: .value("累積", item.value))
                            .foregroundStyle(Theme.accent.opacity(0.18))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
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
                    .frame(height: 90)
                }

                HStack {
                    Text(analysis.recentFiveDayNetLots >= 0 ? "短線偏多" : "短線偏空")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("結論：\(analysis.mainForceVerdict)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.bullish)
                }
            } else {
                Text("此檔無三大法人資料可供統計。")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
                    .frame(height: 110)
            }
        }
    }

    private func chipRow(_ label: String, _ value: Double) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
            Spacer(minLength: 8)
            Text("\(Format.signedInteger(value)) 張")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.changeColor(value))
        }
        .frame(width: 130)
    }
}

/// 面板 16：買賣力分布圖。
struct BuyPowerPanel: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 16, title: "買賣力分布圖", subtitle: "法人 vs 散戶") {
            VStack(spacing: 8) {
                HStack(spacing: 18) {
                    DonutGauge(value: analysis.majorBuyPower, label: "大戶買盤", tint: Theme.bullish)
                    DonutGauge(value: analysis.retailBuyPower, label: "散戶買盤", tint: Theme.warning)
                    DonutGauge(value: analysis.retailSellPressure, label: "散戶賣壓", tint: Theme.bearish)
                }

                if let latest = dataset.latest {
                    Text("資料時間：\(DateFormatter.twDate.string(from: latest.date))"
                         + (analysis.hasInstitutionalData
                            ? "（法人買進／賣出占成交量比例，近 20 日平均）"
                            : "（本檔無法人資料，改以近 20 日價量結構推估）"))
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
    }
}

/// 面板 17：多空強度分布。
struct StrengthPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 17, title: "多空強度分布") {
            VStack(spacing: 8) {
                HStack(spacing: 18) {
                    DonutGauge(value: analysis.bullStrength, label: "多方強度", tint: Theme.bullish)
                    DonutGauge(value: analysis.bearStrength, label: "空方強度", tint: Theme.warning)
                    DonutGauge(value: analysis.volumeStrength, label: "量能強度", tint: Theme.accent)
                }

                HStack(spacing: 6) {
                    Text("信號等級：").font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    Text("\(analysis.signalGrade) 級區")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text("（1 級最強 ～ 5 級最弱，依綜合評分 \(Int(analysis.overallScore))）")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
    }
}

/// 面板 18：主力追蹤總評判。
struct VerdictPanel: View {

    let analysis: AnalysisResult

    var body: some View {
        PanelCard(index: 18, title: "主力追蹤總評判", subtitle: "MAIN FORCE VERDICT") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("主力語意：")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text(analysis.mainForceVerdict)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(Theme.bullish)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        tag("隔日沖", tint: Theme.warning)
                        tag("法人動作", tint: Theme.accent)
                    }
                }

                Text(analysis.aiConclusion)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.6)))
    }
}
