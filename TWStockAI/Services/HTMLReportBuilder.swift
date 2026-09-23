import Foundation

/// 離線 HTML 報告產生器：輸出不依賴網路的單檔分析報告。
enum HTMLReportBuilder {

    static func build(dataset: StockDataset, analysis: AnalysisResult) -> String {
        let identity = dataset.identity
        let latest = dataset.latest

        return """
        <!DOCTYPE html>
        <html lang="zh-Hant">
        <head>
        <meta charset="utf-8">
        <title>\(identity.code) \(identity.name) AI 分析報告</title>
        <style>
          :root { color-scheme: dark; }
          body { background:#0b0e16; color:#e6eaf5; font-family:"PingFang TC","Helvetica Neue",sans-serif; margin:0; padding:28px; }
          h1 { color:#5b8cff; font-size:26px; margin:0 0 6px; }
          h2 { color:#8ab0ff; font-size:16px; margin:26px 0 10px; border-left:3px solid #5b8cff; padding-left:8px; }
          .meta { color:#6b7791; font-size:12px; margin-bottom:18px; }
          table { width:100%; border-collapse:collapse; font-size:12px; margin-bottom:14px; }
          th, td { border:1px solid #232b3d; padding:6px 8px; text-align:right; }
          th { background:#141927; color:#9aa6c1; text-align:center; }
          td.label { text-align:left; color:#9aa6c1; }
          .up { color:#ff5f56; } .down { color:#2ecc71; } .accent { color:#5b8cff; }
          .cards { display:flex; flex-wrap:wrap; gap:10px; }
          .card { background:#141927; border:1px solid #2a3447; border-radius:8px; padding:12px 16px; min-width:150px; }
          .card .k { color:#6b7791; font-size:11px; } .card .v { font-size:17px; font-weight:700; }
          .note { color:#6b7791; font-size:11px; margin-top:24px; border-top:1px solid #232b3d; padding-top:12px; }
        </style>
        </head>
        <body>
        <h1>\(identity.code) \(identity.name)　AI 主力行為判讀報告</h1>
        <div class="meta">
          資料來源：\(dataset.badge.priceSource)｜\(dataset.badge.institutionalSource)　
          區間 \(dataset.rangeDescription)，共 \(dataset.quotes.count) 個交易日　
          產生時間 \(DateFormatter.twDate.string(from: Date()))
        </div>

        \(summaryCards(latest: latest, analysis: analysis))

        <h2>AI 決策核心</h2>
        \(decisionTable(analysis.decision))

        <h2>多維度判讀（綜合評分 \(String(format: "%.0f", analysis.overallScore)) / 100，\(analysis.grade.rawValue)）</h2>
        \(radarTable(analysis.radar))

        <h2>健康度綜合評估</h2>
        \(metricTable(analysis.healthMetrics))

        <h2>隔日沖風險分析（風險指數 \(String(format: "%.0f", analysis.dayTradeRiskIndex))，等級 \(analysis.dayTradeRiskLevel)）</h2>
        \(metricTable(analysis.dayTradeRiskMetrics))

        <h2>AI 信心維度</h2>
        \(metricTable(analysis.confidenceMetrics))

        <h2>主力追蹤總評判</h2>
        <p class="accent" style="font-size:20px;font-weight:700;">主力語意：\(analysis.mainForceVerdict)</p>
        <p style="font-size:13px;line-height:1.7;">\(analysis.aiConclusion)</p>

        <h2>技術警示（近 20 個交易日）</h2>
        \(alertTable(analysis.alerts))

        <h2>日 K 與指標明細（最近 30 個交易日）</h2>
        \(quoteTable(dataset: dataset, analysis: analysis))

        <div class="note">
          本報告為 AI 技術分析整理，僅供參考，不構成投資建議。投資有風險，請審慎評估並自負盈虧。
          盤中數據可能即時變動，請依實際成交與官方資訊為準。
        </div>
        </body>
        </html>
        """
    }

    // MARK: - 區塊組裝

    private static func summaryCards(latest: DailyQuote?, analysis: AnalysisResult) -> String {
        guard let latest else { return "" }
        let changeClass = latest.change >= 0 ? "up" : "down"

        let cards: [(String, String, String)] = [
            ("今日收盤價", Format.price(latest.close), changeClass),
            ("今日漲跌", Format.signedPrice(latest.change), changeClass),
            ("今日漲幅", Format.percent(latest.changePercent), changeClass),
            ("成交量(張)", Format.integer(latest.volumeLots), "accent"),
            ("主力成本(20VWAP)", Format.price(analysis.mainForceCost), "accent"),
            ("相對主力成本", Format.percent(analysis.strengthVersusCost), analysis.strengthVersusCost >= 0 ? "up" : "down"),
            ("綜合評分", String(format: "%.0f / 100", analysis.overallScore), "accent"),
            ("隔日沖風險", Format.ratio(analysis.dayTradeRiskIndex), analysis.dayTradeRiskIndex >= 60 ? "up" : "down")
        ]

        let body = cards.map { card in
            "<div class=\"card\"><div class=\"k\">\(card.0)</div><div class=\"v \(card.2)\">\(card.1)</div></div>"
        }.joined()

        return "<div class=\"cards\">\(body)</div>"
    }

    private static func decisionTable(_ decision: DecisionCore) -> String {
        let rows: [(String, String)] = [
            ("整體訊號", decision.headline),
            ("趨勢判斷", decision.trendJudgement),
            ("短線狀態", decision.shortTermState),
            ("主力行為", decision.mainForceBehavior),
            ("籌碼結構", decision.chipStructure),
            ("隔日沖風險", Format.ratio(decision.nextDayRisk)),
            ("籌碼健康度", String(format: "%.0f 分 %@", decision.chipHealthScore, decision.chipHealthNote)),
            ("支撐區間", "\(Format.price(decision.supportLevels.primary)) / \(Format.price(decision.supportLevels.secondary))"),
            ("壓力區間", "\(Format.price(decision.resistanceLevels.primary)) / \(Format.price(decision.resistanceLevels.secondary))"),
            ("風險等級", decision.riskWindow)
        ]
        return keyValueTable(rows)
    }

    private static func radarTable(_ radar: RadarScores) -> String {
        keyValueTable(radar.ordered.map { ($0.label, String(format: "%.0f 分", $0.value)) })
    }

    private static func metricTable(_ metrics: [Metric]) -> String {
        keyValueTable(metrics.map { ($0.label, Format.ratio($0.value)) })
    }

    private static func keyValueTable(_ rows: [(String, String)]) -> String {
        let body = rows.map { "<tr><td class=\"label\">\($0.0)</td><td>\($0.1)</td></tr>" }.joined()
        return "<table>\(body)</table>"
    }

    private static func alertTable(_ alerts: [TechnicalAlert]) -> String {
        guard !alerts.isEmpty else { return "<p style=\"color:#6b7791;font-size:12px;\">近 20 個交易日無觸發警示。</p>" }

        let body = alerts.prefix(30).map { alert in
            """
            <tr>
              <td class="label">\(DateFormatter.twDate.string(from: alert.date))</td>
              <td class="label">\(alert.severity.rawValue)</td>
              <td class="label">\(alert.category)</td>
              <td class="label">\(alert.message)</td>
            </tr>
            """
        }.joined()

        return "<table><tr><th>日期</th><th>等級</th><th>類別</th><th>說明</th></tr>\(body)</table>"
    }

    private static func quoteTable(dataset: StockDataset, analysis: AnalysisResult) -> String {
        let startIndex = max(dataset.quotes.count - 30, 0)

        let body = (startIndex..<dataset.quotes.count).reversed().map { index -> String in
            let quote = dataset.quotes[index]
            let changeClass = quote.change >= 0 ? "up" : "down"

            func field(_ value: Double?) -> String {
                value.map { String(format: "%.2f", $0) } ?? "—"
            }

            return """
            <tr>
              <td class="label">\(DateFormatter.twDate.string(from: quote.date))</td>
              <td>\(Format.price(quote.open))</td>
              <td>\(Format.price(quote.high))</td>
              <td>\(Format.price(quote.low))</td>
              <td class="\(changeClass)">\(Format.price(quote.close))</td>
              <td class="\(changeClass)">\(Format.signedPrice(quote.change))</td>
              <td>\(Format.integer(quote.volumeLots))</td>
              <td>\(field(analysis.ma5[index]))</td>
              <td>\(field(analysis.ma20[index]))</td>
              <td>\(field(analysis.kd[index]?.k))</td>
              <td>\(field(analysis.kd[index]?.d))</td>
              <td>\(field(analysis.macd[index]?.osc))</td>
            </tr>
            """
        }.joined()

        return """
        <table>
          <tr><th>日期</th><th>開盤</th><th>最高</th><th>最低</th><th>收盤</th><th>漲跌</th>
              <th>成交量(張)</th><th>MA5</th><th>MA20</th><th>K</th><th>D</th><th>OSC</th></tr>
          \(body)
        </table>
        """
    }
}
