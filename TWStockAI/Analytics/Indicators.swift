import Foundation

/// 技術指標計算引擎。
/// 全部為純函式（無狀態、無副作用），輸入相同必得相同輸出，方便單元測試。
enum Indicators {

    // MARK: - 移動平均

    /// 簡單移動平均（SMA）。前 period-1 筆為 nil。
    static func sma(_ values: [Double], period: Int) -> [Double?] {
        guard period > 0, values.count >= 1 else { return values.map { _ in nil } }
        return values.indices.map { index in
            guard index + 1 >= period else { return nil }
            let window = values[(index + 1 - period)...index]
            return window.reduce(0, +) / Double(period)
        }
    }

    /// 指數移動平均（EMA）。以前 period 筆的 SMA 作為起始種子。
    static func ema(_ values: [Double], period: Int) -> [Double?] {
        guard period > 0, values.count >= period else { return values.map { _ in nil } }
        let alpha = 2.0 / (Double(period) + 1.0)
        let seed = values.prefix(period).reduce(0, +) / Double(period)

        // 以 reduce 累積，維持函式式風格
        let tail = values.dropFirst(period).reduce(into: [seed]) { accumulated, value in
            let previous = accumulated[accumulated.count - 1]
            accumulated.append(value * alpha + previous * (1 - alpha))
        }

        let leading: [Double?] = Array(repeating: nil, count: period - 1)
        return leading + tail.map { Optional($0) }
    }

    // MARK: - KD 隨機指標

    struct KDPoint {
        let k: Double
        let d: Double
    }

    /// KD 指標（預設 9 日 RSV、K/D 平滑係數 1/3）。
    /// 起始 K、D 皆以 50 為種子，符合台股看盤軟體慣例。
    static func kd(quotes: [DailyQuote], period: Int = 9) -> [KDPoint?] {
        guard quotes.count >= period else { return quotes.map { _ in nil } }

        let rsvSeries: [Double?] = quotes.indices.map { index in
            guard index + 1 >= period else { return nil }
            let window = quotes[(index + 1 - period)...index]
            let highest = window.map(\.high).max() ?? 0
            let lowest = window.map(\.low).min() ?? 0
            let range = highest - lowest
            guard range > 0 else { return 50 }
            return (quotes[index].close - lowest) / range * 100
        }

        var previousK = 50.0
        var previousD = 50.0
        return rsvSeries.map { rsv -> KDPoint? in
            guard let rsv else { return nil }
            let k = previousK * 2 / 3 + rsv / 3
            let d = previousD * 2 / 3 + k / 3
            previousK = k
            previousD = d
            return KDPoint(k: k, d: d)
        }
    }

    // MARK: - MACD

    struct MACDPoint {
        let dif: Double     // 快線（EMA12 - EMA26）
        let macd: Double    // 訊號線（DIF 的 EMA9）
        let osc: Double     // 柱狀體（DIF - MACD）
    }

    /// MACD 指標（12/26/9）。
    static func macd(closes: [Double], fast: Int = 12, slow: Int = 26, signal: Int = 9) -> [MACDPoint?] {
        let fastEMA = ema(closes, period: fast)
        let slowEMA = ema(closes, period: slow)

        let difSeries: [Double?] = zip(fastEMA, slowEMA).map { fastValue, slowValue in
            guard let fastValue, let slowValue else { return nil }
            return fastValue - slowValue
        }

        // 僅對有值的 DIF 區段計算訊號線，再補回原始索引位置
        let firstValidIndex = difSeries.firstIndex { $0 != nil } ?? difSeries.count
        let compactDIF = difSeries.compactMap { $0 }
        let signalCompact = ema(compactDIF, period: signal)

        return difSeries.indices.map { index -> MACDPoint? in
            guard let dif = difSeries[index] else { return nil }
            let offset = index - firstValidIndex
            guard offset >= 0, offset < signalCompact.count, let macdValue = signalCompact[offset] else { return nil }
            return MACDPoint(dif: dif, macd: macdValue, osc: dif - macdValue)
        }
    }

    // MARK: - 交叉事件

    /// 交叉類型。
    enum CrossKind: String {
        case golden = "黃金交叉"
        case death  = "死亡交叉"
        case oscTurnPositive = "柱狀體翻正"
        case oscTurnNegative = "柱狀體翻負"
    }

    struct CrossEvent: Identifiable, Hashable {
        let id = UUID()
        let date: Date
        let kind: String
        let value: Double
    }

    /// 偵測 MACD 的黃金／死亡交叉與柱狀體翻轉。
    static func macdCrosses(dates: [Date], points: [MACDPoint?]) -> [CrossEvent] {
        zip(dates, points).enumerated().compactMap { index, pair -> [CrossEvent]? in
            let (date, current) = pair
            guard index > 0, let current, let previous = points[index - 1] else { return nil }

            let crossEvents: [CrossEvent] = {
                if previous.dif <= previous.macd, current.dif > current.macd {
                    return [CrossEvent(date: date, kind: CrossKind.golden.rawValue, value: current.dif)]
                }
                if previous.dif >= previous.macd, current.dif < current.macd {
                    return [CrossEvent(date: date, kind: CrossKind.death.rawValue, value: current.dif)]
                }
                return []
            }()

            let oscEvents: [CrossEvent] = {
                if previous.osc <= 0, current.osc > 0 {
                    return [CrossEvent(date: date, kind: CrossKind.oscTurnPositive.rawValue, value: current.osc)]
                }
                if previous.osc >= 0, current.osc < 0 {
                    return [CrossEvent(date: date, kind: CrossKind.oscTurnNegative.rawValue, value: current.osc)]
                }
                return []
            }()

            let merged = crossEvents + oscEvents
            return merged.isEmpty ? nil : merged
        }
        .flatMap { $0 }
    }

    /// 偵測 KD 的黃金／死亡交叉。
    static func kdCrosses(dates: [Date], points: [KDPoint?]) -> [CrossEvent] {
        zip(dates, points).enumerated().compactMap { index, pair -> CrossEvent? in
            let (date, current) = pair
            guard index > 0, let current, let previous = points[index - 1] else { return nil }
            if previous.k <= previous.d, current.k > current.d {
                return CrossEvent(date: date, kind: CrossKind.golden.rawValue, value: current.k)
            }
            if previous.k >= previous.d, current.k < current.d {
                return CrossEvent(date: date, kind: CrossKind.death.rawValue, value: current.k)
            }
            return nil
        }
    }

    // MARK: - 其他統計量

    /// RSI（相對強弱指標，預設 14 日）。
    static func rsi(closes: [Double], period: Int = 14) -> [Double?] {
        guard closes.count > period else { return closes.map { _ in nil } }
        let changes = zip(closes.dropFirst(), closes).map { $0 - $1 }
        let gains = changes.map { max($0, 0) }
        let losses = changes.map { max(-$0, 0) }

        let averageGain = smoothedAverage(gains, period: period)
        let averageLoss = smoothedAverage(losses, period: period)

        let body: [Double?] = zip(averageGain, averageLoss).map { gain, loss in
            guard let gain, let loss else { return nil }
            guard loss > 0 else { return 100 }
            let rs = gain / loss
            return 100 - 100 / (1 + rs)
        }
        return [nil] + body
    }

    /// Wilder 平滑平均，供 RSI 使用。
    private static func smoothedAverage(_ values: [Double], period: Int) -> [Double?] {
        guard values.count >= period else { return values.map { _ in nil } }
        let seed = values.prefix(period).reduce(0, +) / Double(period)
        let tail = values.dropFirst(period).reduce(into: [seed]) { accumulated, value in
            let previous = accumulated[accumulated.count - 1]
            accumulated.append((previous * Double(period - 1) + value) / Double(period))
        }
        let leading: [Double?] = Array(repeating: nil, count: period - 1)
        return leading + tail.map { Optional($0) }
    }

    /// 成交量加權平均價（VWAP），常用來推估主力成本。
    static func vwap(quotes: [DailyQuote], period: Int = 20) -> Double? {
        let window = quotes.suffix(period)
        guard !window.isEmpty else { return nil }
        let typicalPrices = window.map { ($0.high + $0.low + $0.close) / 3 }
        let weights = window.map(\.volumeLots)
        let weightSum = weights.reduce(0, +)
        guard weightSum > 0 else {
            return typicalPrices.reduce(0, +) / Double(typicalPrices.count)
        }
        return zip(typicalPrices, weights).map(*).reduce(0, +) / weightSum
    }

    /// 年化波動率（以日報酬標準差推算，一年 252 個交易日）。
    static func annualizedVolatility(closes: [Double], period: Int = 20) -> Double? {
        let window = Array(closes.suffix(period + 1))
        guard window.count > 2 else { return nil }
        let returns = zip(window.dropFirst(), window).map { log($0 / $1) }
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count - 1)
        return sqrt(variance) * sqrt(252) * 100
    }
}
