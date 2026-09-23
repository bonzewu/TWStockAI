import Foundation

/// AI 主力行為判讀引擎。
///
/// 設計原則：
/// - 全部結論皆由「真實市場資料 + 明確可解釋的規則」推導，不使用亂數，不產生模擬數據。
/// - 以純函式組合的方式計算，每個面板對應一個獨立的小函式，方便個別測試與調整。
enum AIAnalyzer {

    /// 主分析入口：輸入資料集，輸出完整的 18 面板分析結果。
    static func analyze(dataset: StockDataset) -> AnalysisResult? {
        let quotes = dataset.quotes
        guard quotes.count >= 20, let latest = quotes.last else { return nil }

        let closes = quotes.map(\.close)
        let volumes = quotes.map(\.volumeLots)

        // ---- 基礎指標 ----
        let ma5 = Indicators.sma(closes, period: 5)
        let ma10 = Indicators.sma(closes, period: 10)
        let ma20 = Indicators.sma(closes, period: 20)
        let ma60 = Indicators.sma(closes, period: 60)
        let kdSeries = Indicators.kd(quotes: quotes)
        let macdSeries = Indicators.macd(closes: closes)
        let rsiSeries = Indicators.rsi(closes: closes)

        let mainForceCost = Indicators.vwap(quotes: quotes, period: 20) ?? latest.close
        let volatility = Indicators.annualizedVolatility(closes: closes) ?? 0
        let strengthVersusCost = (latest.close - mainForceCost) / mainForceCost * 100

        // ---- 支撐壓力 ----
        let recentWindow = quotes.suffix(60)
        let shortWindow = quotes.suffix(20)
        let pressureZone = recentWindow.map(\.high).max() ?? latest.high
        let shortPressure = shortWindow.map(\.high).max() ?? latest.high
        let supportZone = shortWindow.map(\.low).min() ?? latest.low
        let deepSupport = recentWindow.map(\.low).min() ?? latest.low

        // ---- 六大面向分數 ----
        let radar = radarScores(
            quotes: quotes, closes: closes, volumes: volumes,
            ma5: ma5, ma10: ma10, ma20: ma20,
            kd: kdSeries, macd: macdSeries, rsi: rsiSeries,
            institutional: dataset.institutional, volatility: volatility
        )
        // 綜合評分只計入有資料的面向；缺法人資料時以其餘五軸平均，不補中性值
        let availableScores = radar.availableValues
        let overallScore = availableScores.reduce(0, +) / Double(max(availableScores.count, 1))
        let hasInstitutional = !dataset.institutional.isEmpty

        // ---- 法人統計 ----
        let cumulativeNet = dataset.institutional.map(\.total).reduce(0, +)
        let recentFiveNet = dataset.institutional.suffix(5).map(\.total).reduce(0, +)

        // ---- 隔日沖風險 ----
        let dayTrade = dayTradeRisk(quotes: quotes, institutional: dataset.institutional)

        // ---- 多空能量（以近 20 日紅黑 K 量能佔比計算）----
        let energy = bullBearEnergy(quotes: quotes)

        // ---- 健康度五項 ----
        let health = healthMetrics(radar: radar, volatility: volatility, dayTradeRisk: dayTrade.index)
        let healthValues = health.compactMap(\.value)
        let healthAverage = healthValues.reduce(0, +) / Double(max(healthValues.count, 1))

        // ---- 決策核心 ----
        let decision = decisionCore(
            latest: latest, radar: radar, overallScore: overallScore,
            strengthVersusCost: strengthVersusCost,
            recentFiveNet: recentFiveNet, dayTradeIndex: dayTrade.index,
            chipHealth: health.first?.value ?? 50, hasInstitutional: hasInstitutional,
            support: (supportZone, deepSupport),
            resistance: (pressureZone, shortPressure)
        )

        // ---- 預測路徑 ----
        let forecast = forecastPath(closes: closes, latest: latest.close)

        // ---- 市場情緒 ----
        let sentiment = sentimentScores(radar: radar, energy: energy, dayTradeIndex: dayTrade.index)

        return AnalysisResult(
            mainForceCost: mainForceCost,
            pressureZone: pressureZone,
            supportZone: supportZone,
            decision: decision,
            radar: radar,
            overallScore: overallScore,
            grade: Grade.from(score: overallScore),
            heatCells: heatMap(quotes: quotes),
            heatLegend: heatLegend(quotes: quotes, mainForceCost: mainForceCost),
            riskRadar: riskRadar(radar: radar, volatility: volatility, dayTradeIndex: dayTrade.index),
            mainForceRiskLevel: riskLabel(for: dayTrade.index),
            mainForceRiskIndex: dayTrade.index,
            forecast: forecast.points,
            upProbability: forecast.up,
            flatProbability: forecast.flat,
            downProbability: forecast.down,
            directionBias: forecast.up >= forecast.down ? "多頭 \(Int(forecast.up.rounded()))%" : "空頭 \(Int(forecast.down.rounded()))%",
            annualizedDrift: forecast.annualizedDrift,
            strengthVersusCost: strengthVersusCost,
            hasInstitutionalData: hasInstitutional,
            institutionalSeries: dataset.institutional,
            cumulativeNetLots: cumulativeNet,
            recentFiveDayNetLots: recentFiveNet,
            dayTradeRiskMetrics: dayTrade.metrics,
            dayTradeRiskLevel: riskLabel(for: dayTrade.index),
            dayTradeRiskIndex: dayTrade.index,
            bullEnergy: energy.bull,
            bearEnergy: energy.bear,
            bullBearRatio: energy.ratio,
            healthMetrics: health,
            healthSummary: healthSummary(average: healthAverage),
            healthAverage: healthAverage,
            signalRows: signalRows(radar: radar, decision: decision, dayTradeIndex: dayTrade.index),
            signalLight: signalLight(score: overallScore, dayTradeIndex: dayTrade.index),
            marketSentiment: sentiment.market,
            retailSentiment: sentiment.retail,
            institutionalSentiment: sentiment.institutional,
            mainForceSentiment: sentiment.mainForce,
            confidenceMetrics: confidenceMetrics(dataset: dataset, radar: radar),
            majorBuyPower: sentiment.majorBuy,
            retailBuyPower: 100 - sentiment.majorBuy,
            retailSellPressure: sentiment.retailSell,
            bullStrength: energy.bull,
            bearStrength: energy.bear,
            volumeStrength: radar.liquidity,
            signalGrade: signalGrade(score: overallScore),
            mainForceVerdict: verdict(
                strengthVersusCost: strengthVersusCost, recentFiveNet: recentFiveNet,
                radar: radar, hasInstitutional: hasInstitutional
            ),
            aiConclusion: conclusionText(
                dataset: dataset, recentFiveNet: recentFiveNet,
                strengthVersusCost: strengthVersusCost,
                rsi: rsiSeries.last.flatMap { $0 }, radar: radar
            ),
            alerts: alerts(quotes: quotes, ma5: ma5, ma20: ma20, kd: kdSeries, macd: macdSeries, rsi: rsiSeries, institutional: dataset.institutional),
            ma5: ma5, ma10: ma10, ma20: ma20, ma60: ma60,
            kd: kdSeries, macd: macdSeries,
            macdEvents: Indicators.macdCrosses(dates: quotes.map(\.date), points: macdSeries),
            kdEvents: Indicators.kdCrosses(dates: quotes.map(\.date), points: kdSeries),
            rsiLatest: rsiSeries.last.flatMap { $0 }
        )
    }

    // MARK: - 六大面向評分

    private static func radarScores(
        quotes: [DailyQuote], closes: [Double], volumes: [Double],
        ma5: [Double?], ma10: [Double?], ma20: [Double?],
        kd: [Indicators.KDPoint?], macd: [Indicators.MACDPoint?], rsi: [Double?],
        institutional: [InstitutionalFlow], volatility: Double
    ) -> RadarScores {

        let latestClose = closes.last ?? 0

        // 趨勢：均線多頭排列（40）＋ 收盤站上 MA20（30）＋ MA20 斜率（30）
        let trendScore: Double = {
            let value5 = ma5.last.flatMap { $0 } ?? latestClose
            let value10 = ma10.last.flatMap { $0 } ?? latestClose
            let value20 = ma20.last.flatMap { $0 } ?? latestClose
            let alignment = (value5 > value10 ? 20.0 : 0) + (value10 > value20 ? 20.0 : 0)
            let abovePosition = latestClose > value20 ? 30.0 : 0
            let slope: Double = {
                let recent = ma20.suffix(10).compactMap { $0 }
                guard let first = recent.first, let last = recent.last, first > 0 else { return 15 }
                let change = (last - first) / first * 100
                return clamp(15 + change * 3, 0, 30)
            }()
            return clamp(alignment + abovePosition + slope, 0, 100)
        }()

        // 動能：RSI（40）＋ KD 位置（30）＋ MACD 柱狀體方向（30）
        let momentumScore: Double = {
            let rsiValue = rsi.last.flatMap { $0 } ?? 50
            let rsiPart = clamp(rsiValue, 0, 100) * 0.4
            let kdPart: Double = {
                guard let point = kd.last.flatMap({ $0 }) else { return 15 }
                return clamp(point.k, 0, 100) * 0.3
            }()
            let macdPart: Double = {
                guard let point = macd.last.flatMap({ $0 }) else { return 15 }
                let previousOSC = macd.dropLast().last.flatMap { $0 }?.osc ?? 0
                let rising = point.osc > previousOSC
                return (point.osc > 0 ? 18.0 : 6.0) + (rising ? 12.0 : 0)
            }()
            return clamp(rsiPart + kdPart + macdPart, 0, 100)
        }()

        // 籌碼：有法人資料時看買賣超佔均量比例；
        // 沒有法人資料時（例如上櫃股）改以「收盤相對 20 日 VWAP 的位置」推估籌碼強弱，
        // 這是純價量推導，不會冒充法人訊號。
        let chipScore: Double = {
            let averageVolume = volumes.suffix(20).reduce(0, +) / Double(max(min(volumes.count, 20), 1))

            guard !institutional.isEmpty else {
                guard let cost = Indicators.vwap(quotes: quotes, period: 20), cost > 0,
                      let latestClose = closes.last else { return 50 }
                let deviation = (latestClose - cost) / cost * 100
                return clamp(50 + deviation * 3, 0, 100)
            }

            guard averageVolume > 0 else { return 50 }
            let net = institutional.suffix(5).map(\.total).reduce(0, +)
            let ratio = net / (averageVolume * 5) * 100
            return clamp(50 + ratio * 2.5, 0, 100)
        }()

        // 流動性：近 5 日均量 ÷ 近 20 日均量
        let liquidityScore: Double = {
            let shortAverage = volumes.suffix(5).reduce(0, +) / Double(max(min(volumes.count, 5), 1))
            let longAverage = volumes.suffix(20).reduce(0, +) / Double(max(min(volumes.count, 20), 1))
            guard longAverage > 0 else { return 50 }
            return clamp(shortAverage / longAverage * 55, 0, 100)
        }()

        // 波動：年化波動率越低分數越高（25% 對應 70 分，60% 以上低於 30 分）
        let volatilityScore = clamp(100 - volatility * 1.35, 5, 100)

        // 法人：近 5 日法人淨額方向與連續性；沒有公開資料時回傳 nil（標示為無資料）
        let institutionalScore: Double? = {
            guard !institutional.isEmpty else { return nil }
            let recent = institutional.suffix(5)
            let positiveDays = recent.filter { $0.total > 0 }.count
            let net = recent.map(\.total).reduce(0, +)
            let base = Double(positiveDays) / Double(recent.count) * 60
            let directionBonus = net > 0 ? 40.0 : 10.0
            return clamp(base + directionBonus * 0.5, 0, 100)
        }()

        return RadarScores(
            institutional: institutionalScore,
            momentum: momentumScore,
            trend: trendScore,
            chips: chipScore,
            liquidity: liquidityScore,
            volatility: volatilityScore
        )
    }

    // MARK: - 決策核心

    private static func decisionCore(
        latest: DailyQuote, radar: RadarScores, overallScore: Double,
        strengthVersusCost: Double, recentFiveNet: Double, dayTradeIndex: Double,
        chipHealth: Double, hasInstitutional: Bool,
        support: (Double, Double), resistance: (Double, Double)
    ) -> DecisionCore {

        let headline: String = {
            switch overallScore {
            case 75...: return "AI BULLISH"
            case 55..<75 where dayTradeIndex < 60: return "AI NEUTRAL"
            case 40..<75: return "AI CAUTION"
            default: return "AI BEARISH"
            }
        }()

        let trendJudgement: String = {
            switch radar.trend {
            case 75...: return "多頭延續"
            case 55..<75: return "中性偏多"
            case 40..<55: return "中性整理"
            default: return "偏空修正"
            }
        }()

        let shortTermState: String = {
            switch radar.momentum {
            case 70...: return "強勢突破"
            case 45..<70: return "區間震盪"
            default: return "弱勢回檔"
            }
        }()

        let mainForceBehavior: String = {
            // 沒有法人資料時不能推論法人動向，改以價量位置描述，並標明推估來源
            guard hasInstitutional else {
                if strengthVersusCost > 8 { return "價量偏強（價量推估）" }
                if strengthVersusCost < -8 { return "價量偏弱（價量推估）" }
                return "區間整理（價量推估）"
            }

            if recentFiveNet > 0, strengthVersusCost > 5 { return "積極拉抬" }
            if recentFiveNet > 0 { return "低檔承接" }
            if strengthVersusCost > 10 { return "調節減碼" }
            return "觀望整理"
        }()

        let chipStructure: String = {
            switch radar.chips {
            case 65...: return "轉強"
            case 45..<65: return "中性"
            default: return "偏弱"
            }
        }()

        let chipHealthNote: String = {
            switch chipHealth {
            case 65...: return "（結構健康）"
            case 45..<65: return "（中性觀望）"
            default: return "（偏弱回檔）"
            }
        }()

        let riskWindow: String = {
            switch dayTradeIndex {
            case 70...: return "1 ～ 2 交易日"
            case 50..<70: return "2 ～ 3 交易日"
            default: return "3 ～ 5 交易日"
            }
        }()

        return DecisionCore(
            headline: headline,
            trendJudgement: trendJudgement,
            shortTermState: shortTermState,
            mainForceBehavior: mainForceBehavior,
            chipStructure: chipStructure,
            nextDayRisk: dayTradeIndex,
            chipHealthScore: chipHealth,
            chipHealthNote: chipHealthNote,
            supportLevels: support,
            resistanceLevels: resistance,
            riskWindow: riskWindow
        )
    }

    // MARK: - 隔日沖風險

    private static func dayTradeRisk(
        quotes: [DailyQuote], institutional: [InstitutionalFlow]
    ) -> (metrics: [Metric], index: Double) {

        let recent = Array(quotes.suffix(20))
        let latest = quotes.last

        // 主力賣出異常：法人近 5 日賣超相對均量的比重
        let averageVolume = recent.map(\.volumeLots).reduce(0, +) / Double(max(recent.count, 1))
        let sellPressure: Double = {
            guard averageVolume > 0 else { return 50 }

            // 無法人資料時改以「上影線佔比 + 量增」推估賣壓，屬純價量推導
            guard !institutional.isEmpty else {
                guard let latest else { return 50 }
                let range = latest.high - latest.low
                let upperShadow = range > 0 ? (latest.high - max(latest.open, latest.close)) / range : 0
                let volumeRatio = latest.volumeLots / averageVolume
                // 權重刻意壓低，避免長上影線搭配爆量時直接觸頂而失去鑑別度
                return clamp(upperShadow * 60 + (volumeRatio - 1) * 25 + 20, 0, 100)
            }

            let net = institutional.suffix(5).map(\.total).reduce(0, +)
            return clamp(50 - net / (averageVolume * 5) * 250, 0, 100)
        }()

        // 籌碼換手率：當日量 ÷ 20 日均量
        let turnover: Double = {
            guard let latest, averageVolume > 0 else { return 50 }
            return clamp(latest.volumeLots / averageVolume * 55, 0, 100)
        }()

        // 沖銷比例：以成交筆數對成交張數的比值推估（筆數多且單筆小＝當沖活躍）
        let dayTradeRatio: Double = {
            guard let latest, latest.volumeLots > 0 else { return 50 }
            let lotsPerTicket = latest.volumeLots / Double(max(latest.turnoverCount, 1))
            return clamp(100 - lotsPerTicket * 45, 5, 100)
        }()

        // 隔日回檔風險：上影線長度佔當日全幅的比例
        let pullbackRisk: Double = {
            guard let latest else { return 50 }
            let range = latest.high - latest.low
            guard range > 0 else { return 30 }
            let upperShadow = latest.high - max(latest.open, latest.close)
            return clamp(upperShadow / range * 140, 0, 100)
        }()

        // 日內波動率：近 5 日平均振幅
        let intradayVolatility: Double = {
            let amplitudes = quotes.suffix(5).compactMap { quote -> Double? in
                guard quote.low > 0 else { return nil }
                return (quote.high - quote.low) / quote.low * 100
            }
            guard !amplitudes.isEmpty else { return 40 }
            let average = amplitudes.reduce(0, +) / Double(amplitudes.count)
            return clamp(average * 14, 0, 100)
        }()

        let metrics = [
            Metric("主力賣出異常", sellPressure),
            Metric("籌碼換手率", turnover),
            Metric("沖銷比例", dayTradeRatio),
            Metric("隔日回檔風險", pullbackRisk),
            Metric("日內波動率", intradayVolatility)
        ]

        // 加權合成總風險指數
        let index = clamp(
            sellPressure * 0.25 + turnover * 0.2 + dayTradeRatio * 0.2
            + pullbackRisk * 0.2 + intradayVolatility * 0.15,
            0, 100
        )
        return (metrics, index)
    }

    // MARK: - 多空能量

    private static func bullBearEnergy(quotes: [DailyQuote]) -> (bull: Double, bear: Double, ratio: Double) {
        let window = quotes.suffix(20)
        let bullVolume = window.filter(\.isBullish).map(\.volumeLots).reduce(0, +)
        let bearVolume = window.filter { !$0.isBullish }.map(\.volumeLots).reduce(0, +)
        let total = bullVolume + bearVolume
        guard total > 0 else { return (50, 50, 1) }
        let bull = bullVolume / total * 100
        return (bull, 100 - bull, bearVolume > 0 ? bullVolume / bearVolume : 99)
    }

    // MARK: - 健康度

    private static func healthMetrics(radar: RadarScores, volatility: Double, dayTradeRisk: Double) -> [Metric] {
        // 籌碼健康度：有法人資料時取兩者平均，否則只採計價量推導的籌碼分數
        let chipHealth = radar.institutional.map { (radar.chips + $0) / 2 } ?? radar.chips

        // 法人支撐度：沒有法人資料就標示無資料，不以其他指標替代
        let institutionalSupport = radar.institutional.map {
            clamp($0 * 0.7 + (100 - dayTradeRisk) * 0.3, 0, 100)
        }

        return [
            Metric("籌碼健康度", clamp(chipHealth, 0, 100)),
            Metric("技術結構度", clamp((radar.trend * 0.6 + radar.momentum * 0.4), 0, 100)),
            Metric("資金動能度", radar.liquidity),
            Metric("波動風險度", clamp(100 - radar.volatility, 0, 100), note: String(format: "年化 %.1f%%", volatility)),
            Metric("法人支撐度", institutionalSupport)
        ]
    }

    private static func healthSummary(average: Double) -> String {
        switch average {
        case 70...: return "良好"
        case 50..<70: return "普通"
        case 35..<50: return "偏弱"
        default: return "不佳"
        }
    }

    // MARK: - 信號燈

    private static func signalRows(radar: RadarScores, decision: DecisionCore, dayTradeIndex: Double) -> [(String, String)] {
        [
            ("趨勢", decision.trendJudgement),
            ("籌碼", decision.chipStructure == "轉強" ? "籌碼轉強" : (decision.chipStructure == "中性" ? "籌碼中性" : "偏弱回檔")),
            ("動能", radar.momentum >= 60 ? "動能轉強" : (radar.momentum >= 45 ? "動能持平" : "動能轉弱")),
            ("風險", dayTradeIndex >= 70 ? "風險偏高" : (dayTradeIndex >= 50 ? "風險可控" : "風險偏低")),
            ("結論", signalLight(score: (radar.trend + radar.momentum + radar.chips) / 3, dayTradeIndex: dayTradeIndex).rawValue)
        ]
    }

    private static func signalLight(score: Double, dayTradeIndex: Double) -> SignalLight {
        if score >= 65, dayTradeIndex < 65 { return .green }
        if score < 45 || dayTradeIndex >= 80 { return .red }
        return .yellow
    }

    private static func signalGrade(score: Double) -> Int {
        switch score {
        case 80...: return 1
        case 65..<80: return 2
        case 50..<65: return 3
        case 35..<50: return 4
        default: return 5
        }
    }

    // MARK: - 情緒與信心

    private static func sentimentScores(
        radar: RadarScores, energy: (bull: Double, bear: Double, ratio: Double), dayTradeIndex: Double
    ) -> (market: Double, retail: Double, institutional: Double?, mainForce: Double, majorBuy: Double, retailSell: Double) {

        let market = clamp((radar.trend * 0.35 + radar.momentum * 0.35 + energy.bull * 0.3), 0, 100)
        let retail = clamp(energy.bull * 0.5 + dayTradeIndex * 0.5, 0, 100)

        // 法人情緒直接反映法人分數；沒有法人資料時維持 nil
        let institutional = radar.institutional

        let mainForce = clamp((radar.chips * 0.6 + (100 - dayTradeIndex) * 0.4), 0, 100)

        // 大戶買盤：有法人資料時混合法人與籌碼，否則只用價量推導的籌碼分數
        let majorBuy = clamp(radar.institutional.map { $0 * 0.5 + radar.chips * 0.5 } ?? radar.chips, 0, 100)
        let retailSell = clamp(100 - majorBuy * 0.6 - energy.bull * 0.2, 0, 100)
        return (market, retail, institutional, mainForce, majorBuy, retailSell)
    }

    private static func confidenceMetrics(dataset: StockDataset, radar: RadarScores) -> [Metric] {
        // 資料完整度：實際交易日數 ÷ 目標 98 日
        let completeness = clamp(Double(dataset.quotes.count) / 98 * 100, 0, 100)
        // 訊號穩定度：各面向分數的離散程度越小越穩定（只計入有資料的面向）
        let values = radar.availableValues
        let mean = values.reduce(0, +) / Double(max(values.count, 1))
        let deviation = sqrt(values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(values.count, 1)))
        let stability = clamp(100 - deviation * 1.8, 0, 100)
        let institutionalCoverage = dataset.institutional.isEmpty ? 0.0 : 100.0

        return [
            Metric("AI CONFIDENCE", clamp(mean * 0.6 + stability * 0.4, 0, 100)),
            Metric("模型準確度", clamp(stability * 0.7 + completeness * 0.3, 0, 100)),
            Metric("資料完整度", completeness),
            Metric("訊號穩定度", stability),
            Metric("策略適用度", clamp((completeness * 0.4 + institutionalCoverage * 0.3 + stability * 0.3), 0, 100))
        ]
    }

    // MARK: - 預測路徑

    private static func forecastPath(closes: [Double], latest: Double)
    -> (points: [ForecastPoint], up: Double, flat: Double, down: Double, annualizedDrift: Double) {

        let window = Array(closes.suffix(61))
        guard window.count > 5 else {
            return ([], 33, 34, 33, 0)
        }

        // 以對數報酬統計推估漂移與波動
        let returns = zip(window.dropFirst(), window).map { log($0 / $1) }
        let drift = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - drift, 2) }.reduce(0, +) / Double(max(returns.count - 1, 1))
        let sigma = sqrt(variance)

        let horizons: [(label: String, days: Int)] = [("今日", 0), ("3日後", 3), ("5日後", 5), ("10日後", 10)]
        let points = horizons.map { horizon -> ForecastPoint in
            let days = Double(horizon.days)
            let expected = latest * exp(drift * days)
            let band = latest * sigma * sqrt(days) * 1.28   // 約 80% 信賴區間
            return ForecastPoint(
                horizonLabel: horizon.label,
                horizonDays: horizon.days,
                bullish: expected + band,
                neutral: expected,
                bearish: max(expected - band, 0)
            )
        }

        // 以歷史日報酬分布計算上漲／震盪／下跌機率（±0.5% 視為震盪）
        let threshold = 0.005
        let upDays = returns.filter { $0 > threshold }.count
        let downDays = returns.filter { $0 < -threshold }.count
        let flatDays = returns.count - upDays - downDays
        let total = Double(returns.count)

        return (
            points,
            Double(upDays) / total * 100,
            Double(flatDays) / total * 100,
            Double(downDays) / total * 100,
            (exp(drift * 252) - 1) * 100
        )
    }

    // MARK: - 籌碼熱區

    /// 將近 60 日資料切成「時間欄 × 價格列」的成交量密度矩陣。
    private static func heatMap(quotes: [DailyQuote], columns: Int = 12, buckets: Int = 18) -> [HeatCell] {
        let window = Array(quotes.suffix(60))
        guard window.count >= columns,
              let lowest = window.map(\.low).min(),
              let highest = window.map(\.high).max(),
              highest > lowest else { return [] }

        let bucketSize = (highest - lowest) / Double(buckets)
        let chunkSize = max(window.count / columns, 1)

        // 逐欄統計每個價格區間的成交量
        let matrix: [[Double]] = (0..<columns).map { column in
            let start = column * chunkSize
            let end = min(start + chunkSize, window.count)
            guard start < end else { return Array(repeating: 0, count: buckets) }

            return window[start..<end].reduce(into: Array(repeating: 0.0, count: buckets)) { accumulated, quote in
                let index = min(Int((quote.close - lowest) / bucketSize), buckets - 1)
                accumulated[max(index, 0)] += quote.volumeLots
            }
        }

        let maximum = matrix.flatMap { $0 }.max() ?? 1
        guard maximum > 0 else { return [] }

        return matrix.enumerated().flatMap { columnIndex, column in
            column.enumerated().map { bucketIndex, volume in
                HeatCell(
                    columnIndex: columnIndex,
                    priceBucket: bucketIndex,
                    priceLow: lowest + Double(bucketIndex) * bucketSize,
                    priceHigh: lowest + Double(bucketIndex + 1) * bucketSize,
                    intensity: volume / maximum
                )
            }
        }
    }

    /// 熱區圖圖例：依收盤價相對主力成本的位置，統計成交量落在各區的比重。
    private static func heatLegend(quotes: [DailyQuote], mainForceCost: Double) -> [HeatLegendItem] {
        let window = quotes.suffix(60)
        let totalVolume = window.map(\.volumeLots).reduce(0, +)
        guard totalVolume > 0, mainForceCost > 0 else { return [] }

        /// 依「收盤價相對主力成本的偏離度」分類。
        func share(_ predicate: (Double) -> Bool) -> Double {
            window.filter { predicate(($0.close - mainForceCost) / mainForceCost * 100) }
                .map(\.volumeLots).reduce(0, +) / totalVolume * 100
        }

        return [
            HeatLegendItem(label: "壓力區", percentage: share { $0 > 5 }),
            HeatLegendItem(label: "大量成交區", percentage: share { $0 > 2 && $0 <= 5 }),
            HeatLegendItem(label: "密集成交區", percentage: share { $0 > -2 && $0 <= 2 }),
            HeatLegendItem(label: "價平區", percentage: share { $0 > -5 && $0 <= -2 }),
            HeatLegendItem(label: "支撐區", percentage: share { $0 <= -5 })
        ]
    }

    // MARK: - 風險雷達

    private static func riskRadar(radar: RadarScores, volatility: Double, dayTradeIndex: Double) -> [RadarAxis] {
        [
            RadarAxis("流動性風險", clamp(100 - radar.liquidity, 0, 100)),
            RadarAxis("波動風險", clamp(volatility * 1.35, 0, 100)),
            RadarAxis("趨勢風險", clamp(100 - radar.trend, 0, 100)),
            RadarAxis("法人風險", radar.institutional.map { clamp(100 - $0, 0, 100) }),
            RadarAxis("籌碼風險", clamp(100 - radar.chips, 0, 100))
        ]
    }

    private static func riskLabel(for index: Double) -> String {
        switch index {
        case 70...: return "高"
        case 45..<70: return "中"
        default: return "低"
        }
    }

    // MARK: - 主力語意與 AI 結論

    private static func verdict(
        strengthVersusCost: Double, recentFiveNet: Double,
        radar: RadarScores, hasInstitutional: Bool
    ) -> String {
        // 沒有法人資料時，結論只依價量給出，不冒充主力籌碼判讀
        guard hasInstitutional else {
            if strengthVersusCost > 8, radar.trend >= 60 { return "價量走強" }
            if strengthVersusCost < -8 { return "價量轉弱" }
            return "區間整理"
        }

        switch (recentFiveNet > 0, strengthVersusCost > 5) {
        case (true, true): return "積極作多"
        case (true, false): return "低檔布局"
        case (false, true): return "調節減碼"
        case (false, false): return radar.trend >= 55 ? "區間整理" : "觀望偏空"
        }
    }

    private static func conclusionText(
        dataset: StockDataset, recentFiveNet: Double,
        strengthVersusCost: Double, rsi: Double?, radar: RadarScores
    ) -> String {
        let vwapText = String(format: "%+.1f%%", strengthVersusCost)
        let rsiText = rsi.map { String(format: "%.0f", $0) } ?? "—"
        let suggestion: String = {
            switch radar.trend {
            case 70...: return "短線可順勢偏多操作，留意壓力區賣壓。"
            case 45..<70: return "短線宜區間操作，等待量能表態。"
            default: return "短線宜保守，待均線重新轉強再行評估。"
            }
        }()

        // 沒有法人資料時，結論必須說明推導基礎只有價量，不得出現法人字眼
        guard !dataset.institutional.isEmpty else {
            return "AI 結論：本檔（\(dataset.identity.market.rawValue)）無三大法人公開資料，"
                + "以下僅依價量研判（收盤相對 20 日 VWAP \(vwapText)、RSI \(rsiText)）：\(suggestion)"
                + "法人相關面板一律標示為無資料，不提供推估值。"
        }

        let netText = String(format: "%+.0f 張", recentFiveNet)
        let stance = recentFiveNet >= 0 ? "法人偏多承接" : "法人小幅調節"
        return "AI 結論：經近 5 日主力行為綜合研判（法人近 5 日合計 \(netText)、收盤相對 20 日 VWAP \(vwapText)、RSI \(rsiText)），\(stance)，\(suggestion)"
    }

    // MARK: - 技術警示（任務二）

    private static func alerts(
        quotes: [DailyQuote], ma5: [Double?], ma20: [Double?],
        kd: [Indicators.KDPoint?], macd: [Indicators.MACDPoint?], rsi: [Double?],
        institutional: [InstitutionalFlow]
    ) -> [TechnicalAlert] {

        let recentRange = max(quotes.count - 20, 0)..<quotes.count

        // 均線與指標類警示
        let indicatorAlerts: [TechnicalAlert] = recentRange.flatMap { index -> [TechnicalAlert] in
            let quote = quotes[index]
            var results: [TechnicalAlert] = []

            // 跌破／站上 20 日均線
            if index > 0, let currentMA = ma20[index], let previousMA = ma20[index - 1] {
                let previousClose = quotes[index - 1].close
                if previousClose >= previousMA, quote.close < currentMA {
                    results.append(TechnicalAlert(date: quote.date, severity: .high, category: "均線",
                                                  message: String(format: "收盤 %.2f 跌破 MA20（%.2f），短多結構轉弱。", quote.close, currentMA)))
                }
                if previousClose <= previousMA, quote.close > currentMA {
                    results.append(TechnicalAlert(date: quote.date, severity: .medium, category: "均線",
                                                  message: String(format: "收盤 %.2f 站上 MA20（%.2f），短線轉強。", quote.close, currentMA)))
                }
            }

            // KD 超買超賣
            if let point = kd[index] {
                if point.k >= 80, point.d >= 80 {
                    results.append(TechnicalAlert(date: quote.date, severity: .medium, category: "KD",
                                                  message: String(format: "KD 進入超買區（K %.1f／D %.1f），慎防高檔震盪。", point.k, point.d)))
                }
                if point.k <= 20, point.d <= 20 {
                    results.append(TechnicalAlert(date: quote.date, severity: .low, category: "KD",
                                                  message: String(format: "KD 進入超賣區（K %.1f／D %.1f），可留意低檔反彈。", point.k, point.d)))
                }
            }

            // MACD 柱狀體翻轉
            if index > 0, let current = macd[index], let previous = macd[index - 1] {
                if previous.osc >= 0, current.osc < 0 {
                    results.append(TechnicalAlert(date: quote.date, severity: .high, category: "MACD",
                                                  message: "MACD 柱狀體翻負，動能由多轉空。"))
                }
                if previous.osc <= 0, current.osc > 0 {
                    results.append(TechnicalAlert(date: quote.date, severity: .low, category: "MACD",
                                                  message: "MACD 柱狀體翻正，動能由空轉多。"))
                }
            }

            // 爆量
            if index >= 20 {
                let average = quotes[(index - 20)..<index].map(\.volumeLots).reduce(0, +) / 20
                if average > 0, quote.volumeLots > average * 2 {
                    results.append(TechnicalAlert(date: quote.date, severity: .medium, category: "量能",
                                                  message: String(format: "成交量 %.0f 張為 20 日均量的 %.1f 倍，量能異常放大。", quote.volumeLots, quote.volumeLots / average)))
                }
            }

            // 單日大跌
            if abs(quote.changePercent) >= 5 {
                results.append(TechnicalAlert(date: quote.date, severity: quote.changePercent < 0 ? .high : .low,
                                              category: "價格",
                                              message: String(format: "單日漲跌幅 %+.2f%%，波動顯著。", quote.changePercent)))
            }

            return results
        }

        // 法人連續賣超警示
        let institutionalAlerts: [TechnicalAlert] = {
            let recent = institutional.suffix(3)
            guard recent.count == 3, recent.allSatisfy({ $0.total < 0 }), let last = recent.last else { return [] }
            let total = recent.map(\.total).reduce(0, +)
            return [TechnicalAlert(date: last.date, severity: .high, category: "法人",
                                   message: String(format: "三大法人連續 3 日賣超，合計 %.0f 張。", total))]
        }()

        return (indicatorAlerts + institutionalAlerts).sorted { $0.date > $1.date }
    }

    // MARK: - 工具

    /// 將數值限制在指定範圍內。
    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

// MARK: - 主力成本結構分布（面板 07）

extension AIAnalyzer {

    /// 分析近 N 日的成交量落在「相對 20 日 VWAP 的哪個價格帶」。
    /// 以滾動視窗逐日計算，輸出可直接餵給堆疊面積圖的資料點。
    static func costStructure(quotes: [DailyQuote], window: Int = 60) -> [CostBandPoint] {
        let startIndex = max(quotes.count - window, 20)
        guard startIndex < quotes.count else { return [] }

        return (startIndex..<quotes.count).flatMap { index -> [CostBandPoint] in
            let slice = Array(quotes[max(index - 19, 0)...index])
            guard let cost = Indicators.vwap(quotes: slice, period: slice.count), cost > 0 else { return [] }

            // 依每日收盤相對成本的偏離度分組，累計成交量
            let grouped = slice.reduce(into: [String: Double]()) { accumulated, quote in
                let deviation = (quote.close - cost) / cost * 100
                let band: String = {
                    switch deviation {
                    case ..<(-5): return "衰竭區(<-5%)"
                    case -5..<(-2): return "套牢區(-2～-5%)"
                    case -2...2: return "主力成本區(±2%)"
                    default: return "大量成交區(+2～5%)"
                    }
                }()
                accumulated[band, default: 0] += quote.volumeLots
            }

            return grouped
                .sorted { $0.key < $1.key }
                .map { CostBandPoint(index: index, date: quotes[index].date, band: $0.key, volume: $0.value) }
        }
    }
}
