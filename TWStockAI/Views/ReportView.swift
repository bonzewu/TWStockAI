import SwiftUI

/// 任務一：綜合分析報告（可直接列印或輸出 PDF 的條列式報告）。
struct ReportView: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            titleBlock

            section("一、行情摘要") {
                if let latest = dataset.latest {
                    grid([
                        ("收盤價", Format.price(latest.close), Theme.changeColor(latest.change)),
                        ("漲跌", Format.signedPrice(latest.change), Theme.changeColor(latest.change)),
                        ("漲跌幅", Format.percent(latest.changePercent), Theme.changeColor(latest.change)),
                        ("開盤", Format.price(latest.open), Theme.textPrimary),
                        ("最高", Format.price(latest.high), Theme.bullish),
                        ("最低", Format.price(latest.low), Theme.bearish),
                        ("成交量", "\(Format.integer(latest.volumeLots)) 張", Theme.textPrimary),
                        ("成交筆數", Format.integer(Double(latest.turnoverCount)), Theme.textPrimary)
                    ])
                }
            }

            section("二、AI 決策核心") {
                VStack(alignment: .leading, spacing: 6) {
                    bullet("整體訊號", analysis.decision.headline, Theme.warning)
                    bullet("趨勢判斷", analysis.decision.trendJudgement, Theme.textPrimary)
                    bullet("短線狀態", analysis.decision.shortTermState, Theme.textPrimary)
                    bullet("主力行為", analysis.decision.mainForceBehavior, Theme.accent)
                    bullet("籌碼結構", analysis.decision.chipStructure, Theme.textPrimary)
                    bullet("支撐區間", "\(Format.price(analysis.decision.supportLevels.primary)) / \(Format.price(analysis.decision.supportLevels.secondary))", Theme.bearish)
                    bullet("壓力區間", "\(Format.price(analysis.decision.resistanceLevels.primary)) / \(Format.price(analysis.decision.resistanceLevels.secondary))", Theme.bullish)
                    bullet("風險視窗", analysis.decision.riskWindow, Theme.textPrimary)
                }
            }

            section("三、多維度評分（綜合 \(Int(analysis.overallScore)) 分，\(analysis.grade.rawValue)）") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(analysis.radar.ordered, id: \.label) { axis in
                        MeterBar(metric: Metric(axis.label, axis.value), tint: Theme.scoreColor(axis.value))
                    }
                }
            }

            section("四、健康度與風險") {
                HStack(alignment: .top, spacing: 30) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("健康度（總評：\(analysis.healthSummary)）")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        ForEach(analysis.healthMetrics) { metric in
                            MeterBar(metric: metric, tint: Theme.scoreColor(metric.value))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("隔日沖風險（指數 \(Int(analysis.dayTradeRiskIndex))，等級 \(analysis.dayTradeRiskLevel)）")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        ForEach(analysis.dayTradeRiskMetrics) { metric in
                            MeterBar(metric: metric, tint: Theme.bullish.opacity(0.85))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            section("五、法人與籌碼") {
                VStack(alignment: .leading, spacing: 6) {
                    if analysis.institutionalSeries.isEmpty {
                        Text("此檔無三大法人資料（上櫃股票或當期無公告）。")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted)
                    } else {
                        bullet("近 \(analysis.institutionalSeries.count) 日累積買賣超", "\(Format.signedInteger(analysis.cumulativeNetLots)) 張", Theme.changeColor(analysis.cumulativeNetLots))
                        bullet("近 5 日買賣超", "\(Format.signedInteger(analysis.recentFiveDayNetLots)) 張", Theme.changeColor(analysis.recentFiveDayNetLots))
                    }
                    bullet("主力成本（20 日 VWAP）", Format.price(analysis.mainForceCost), Theme.accent)
                    bullet("收盤相對主力成本", Format.percent(analysis.strengthVersusCost), Theme.changeColor(analysis.strengthVersusCost))
                }
            }

            section("六、AI 結論") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("主力語意：\(analysis.mainForceVerdict)")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(Theme.bullish)

                    Text(analysis.aiConclusion)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("本報告為 AI 技術分析整理，僅供參考，不構成投資建議。投資有風險，請審慎評估並自負盈虧。")
                .font(.system(size: 10))
                .foregroundColor(Theme.textMuted)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 區塊元件

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(dataset.identity.code) \(dataset.identity.name)　AI 主力行為判讀綜合分析報告")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(Theme.accent)

            Text("資料來源：\(dataset.badge.priceSource)｜\(dataset.badge.institutionalSource)　"
                 + "區間 \(dataset.rangeDescription)，共 \(dataset.quotes.count) 個交易日")
                .font(.system(size: 11))
                .foregroundColor(Theme.textMuted)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.accentSoft)
                .padding(.leading, 8)
                .overlay(Rectangle().frame(width: 3).foregroundColor(Theme.accent), alignment: .leading)

            content()
        }
    }

    private func bullet(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Text("・\(label)")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 190, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
            Spacer()
        }
    }

    private func grid(_ items: [(String, String, Color)]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0).font(.system(size: 10)).foregroundColor(Theme.textMuted)
                    Text(item.1).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(item.2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.panelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
