import Foundation

/// 綜合評分等級。
enum Grade: String {
    case a = "A 級"
    case b = "B 級"
    case c = "C 級"
    case d = "D 級"
    case e = "E 級"

    /// 由 0～100 的綜合分數換算等級。
    static func from(score: Double) -> Grade {
        switch score {
        case 80...: return .a
        case 65..<80: return .b
        case 50..<65: return .c
        case 35..<50: return .d
        default: return .e
        }
    }

    /// 等級字首，用於雷達圖中央的大字。
    var initial: String { String(rawValue.prefix(1)) }
}

/// 訊號燈號。
enum SignalLight: String {
    case green = "綠燈"
    case yellow = "黃燈"
    case red = "紅燈"
}

/// 具名的百分比量測值，供各式進度條／甜甜圈使用。
struct Metric: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: Double       // 0～100
    let note: String?

    init(_ label: String, _ value: Double, note: String? = nil) {
        self.label = label
        self.value = value
        self.note = note
    }
}

/// 雷達圖的六個面向分數。
struct RadarScores {
    let institutional: Double   // 法人
    let momentum: Double        // 動能
    let trend: Double           // 趨勢
    let chips: Double           // 籌碼
    let liquidity: Double       // 流動性
    let volatility: Double      // 波動

    /// 依參考設計的順時針順序輸出（法人 → 動能 → 趨勢 → 籌碼 → 流動性 → 波動）。
    var ordered: [(label: String, value: Double)] {
        [("法人", institutional), ("動能", momentum), ("趨勢", trend),
         ("籌碼", chips), ("流動性", liquidity), ("波動", volatility)]
    }
}

/// AI 決策核心的條列結論。
struct DecisionCore {
    let headline: String            // AI CAUTION / AI BULLISH ...
    let trendJudgement: String      // 趨勢判斷
    let shortTermState: String      // 短線狀態
    let mainForceBehavior: String   // 主力行為
    let chipStructure: String       // 籌碼結構
    let nextDayRisk: Double         // 隔日沖風險（%）
    let chipHealthScore: Double     // 籌碼健康度（分）
    let chipHealthNote: String      // 籌碼健康度註解
    let supportLevels: (primary: Double, secondary: Double)
    let resistanceLevels: (primary: Double, secondary: Double)
    let riskWindow: String          // 風險等級（交易日）
}

/// 累積型預測路徑的單一時間點。
struct ForecastPoint: Identifiable {
    let id = UUID()
    let horizonLabel: String    // 今日 / 3日後 / 5日後 / 10日後
    let horizonDays: Int
    let bullish: Double         // 上緣（樂觀）
    let neutral: Double         // 中位
    let bearish: Double         // 下緣（保守）
}

/// 籌碼熱區圖的單一格。
struct HeatCell: Identifiable {
    let id = UUID()
    let columnIndex: Int    // 時間切片
    let priceBucket: Int    // 價格區間索引
    let priceLow: Double
    let priceHigh: Double
    let intensity: Double   // 0～1 的成交密度
}

/// 熱區圖的分類統計（壓力區／大量成交區／密集成交區／價平區／支撐區）。
struct HeatLegendItem: Identifiable {
    let id = UUID()
    let label: String
    let percentage: Double
}

/// 技術警示（任務二）。
struct TechnicalAlert: Identifiable {
    let id = UUID()
    let date: Date
    let severity: Severity
    let category: String
    let message: String

    enum Severity: String {
        case high = "高"
        case medium = "中"
        case low = "低"
    }
}

/// 完整分析結果：對應參考設計的 18 個面板與四大任務報告所需的全部資料。
struct AnalysisResult {

    // 面板 01：主 K 線圖標記
    let mainForceCost: Double           // 主力成本（20 日 VWAP）
    let pressureZone: Double            // 高檔壓力區
    let supportZone: Double             // 支撐區

    // 面板 02：AI 決策核心
    let decision: DecisionCore

    // 面板 03：多維度判讀
    let radar: RadarScores
    let overallScore: Double
    let grade: Grade

    // 面板 04：籌碼熱區
    let heatCells: [HeatCell]
    let heatLegend: [HeatLegendItem]

    // 面板 05：風險雷達
    let riskRadar: [(label: String, value: Double)]
    let mainForceRiskLevel: String
    let mainForceRiskIndex: Double

    // 面板 06：預測路徑
    let forecast: [ForecastPoint]
    let upProbability: Double
    let flatProbability: Double
    let downProbability: Double
    let directionBias: String
    let annualizedDrift: Double
    let strengthVersusCost: Double      // 收盤相對主力成本（%）

    // 面板 08 / 15：法人行為
    let institutionalSeries: [InstitutionalFlow]
    let cumulativeNetLots: Double
    let recentFiveDayNetLots: Double

    // 面板 09：隔日沖風險分析
    let dayTradeRiskMetrics: [Metric]
    let dayTradeRiskLevel: String
    let dayTradeRiskIndex: Double

    // 面板 10：多空能量
    let bullEnergy: Double
    let bearEnergy: Double
    let bullBearRatio: Double

    // 面板 11：健康度綜合評估
    let healthMetrics: [Metric]
    let healthSummary: String
    let healthAverage: Double

    // 面板 12：主力動態信號
    let signalRows: [(label: String, value: String)]
    let signalLight: SignalLight

    // 面板 13：市場情緒
    let marketSentiment: Double
    let retailSentiment: Double
    let institutionalSentiment: Double
    let mainForceSentiment: Double

    // 面板 14：AI 信心維度
    let confidenceMetrics: [Metric]

    // 面板 16 / 17：買賣力與多空強度
    let majorBuyPower: Double
    let retailBuyPower: Double
    let retailSellPressure: Double
    let bullStrength: Double
    let bearStrength: Double
    let volumeStrength: Double
    let signalGrade: Int

    // 面板 18：主力追蹤總評判
    let mainForceVerdict: String
    let aiConclusion: String

    // 任務二：技術警示
    let alerts: [TechnicalAlert]

    // 任務三／四所需的指標序列
    let ma5: [Double?]
    let ma10: [Double?]
    let ma20: [Double?]
    let ma60: [Double?]
    let kd: [Indicators.KDPoint?]
    let macd: [Indicators.MACDPoint?]
    let macdEvents: [Indicators.CrossEvent]
    let kdEvents: [Indicators.CrossEvent]
    let rsiLatest: Double?
}

/// 主力成本結構分布的單一資料點（堆疊面積圖用）。
struct CostBandPoint: Identifiable {
    let id = UUID()
    let index: Int
    let date: Date
    let band: String        // 衰竭區 / 套牢區 / 主力成本區 / 大量成交區
    let volume: Double      // 該區間的成交量（張）
}
