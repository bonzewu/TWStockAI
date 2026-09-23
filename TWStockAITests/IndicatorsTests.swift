import XCTest
@testable import TWStockAI

/// 技術指標的單元測試：以可手算的資料驗證純函式的正確性。
final class IndicatorsTests: XCTestCase {

    /// 產生一組固定的測試用日 K。
    private func makeQuotes(closes: [Double]) -> [DailyQuote] {
        let calendar = TWSEDateUtility.taipeiCalendar
        let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        return closes.enumerated().map { index, close in
            DailyQuote(
                date: calendar.date(byAdding: .day, value: index, to: base)!,
                open: close - 1,
                high: close + 2,
                low: close - 2,
                close: close,
                change: index == 0 ? 0 : close - closes[index - 1],
                volumeLots: 1_000 + Double(index) * 10,
                turnoverCount: 500
            )
        }
    }

    // MARK: - 移動平均

    func test_簡單移動平均_前期為nil且數值正確() {
        let values: [Double] = [10, 20, 30, 40, 50]
        let result = Indicators.sma(values, period: 3)

        XCTAssertEqual(result.count, 5)
        XCTAssertNil(result[0])
        XCTAssertNil(result[1])
        XCTAssertEqual(result[2]!, 20, accuracy: 0.0001)   // (10+20+30)/3
        XCTAssertEqual(result[3]!, 30, accuracy: 0.0001)
        XCTAssertEqual(result[4]!, 40, accuracy: 0.0001)
    }

    func test_簡單移動平均_資料不足時全為nil() {
        let result = Indicators.sma([10, 20], period: 5)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0 == nil })
    }

    func test_指數移動平均_首值為SMA種子且逐步收斂() {
        let values: [Double] = [10, 20, 30, 40, 50]
        let result = Indicators.ema(values, period: 3)

        XCTAssertNil(result[1])
        XCTAssertEqual(result[2]!, 20, accuracy: 0.0001)   // 種子 = (10+20+30)/3
        // alpha = 2/(3+1) = 0.5；EMA4 = 40*0.5 + 20*0.5 = 30
        XCTAssertEqual(result[3]!, 30, accuracy: 0.0001)
        XCTAssertEqual(result[4]!, 40, accuracy: 0.0001)
    }

    // MARK: - KD

    func test_KD指標_數值恆落在0到100之間() {
        let quotes = makeQuotes(closes: (1...40).map { Double($0) * 1.5 + Double(($0 % 5)) })
        let result = Indicators.kd(quotes: quotes)

        let valid = result.compactMap { $0 }
        XCTAssertFalse(valid.isEmpty)
        XCTAssertTrue(valid.allSatisfy { $0.k >= 0 && $0.k <= 100 })
        XCTAssertTrue(valid.allSatisfy { $0.d >= 0 && $0.d <= 100 })
    }

    func test_KD指標_持續上漲時K值應高於D值() {
        let quotes = makeQuotes(closes: (1...30).map { Double($0) * 2 })
        let result = Indicators.kd(quotes: quotes)

        let last = result.last!!
        XCTAssertGreaterThan(last.k, last.d, "多頭走勢中 K 值應領先 D 值")
        XCTAssertGreaterThan(last.k, 80, "連續上漲應進入超買區")
    }

    // MARK: - MACD

    func test_MACD_柱狀體等於DIF減訊號線() {
        let closes = (1...60).map { Double($0) + sin(Double($0) / 3) * 5 }
        let result = Indicators.macd(closes: closes)

        let valid = result.compactMap { $0 }
        XCTAssertFalse(valid.isEmpty)
        valid.forEach { point in
            XCTAssertEqual(point.osc, point.dif - point.macd, accuracy: 0.0001)
        }
    }

    func test_MACD_資料不足時不產生任何點() {
        let result = Indicators.macd(closes: [10, 11, 12])
        XCTAssertTrue(result.allSatisfy { $0 == nil })
    }

    // MARK: - 交叉偵測

    func test_MACD交叉偵測_能同時抓到黃金與死亡交叉() {
        // 以週期性波動製造多次 DIF 穿越訊號線的情境
        let closes: [Double] = (1...120).map { index in
            100 + sin(Double(index) / 9) * 25
        }
        let quotes = makeQuotes(closes: closes)
        let macd = Indicators.macd(closes: closes)

        let events = Indicators.macdCrosses(dates: quotes.map(\.date), points: macd)
        let golden = events.filter { $0.kind == Indicators.CrossKind.golden.rawValue }
        let death = events.filter { $0.kind == Indicators.CrossKind.death.rawValue }

        XCTAssertFalse(golden.isEmpty, "上漲段應出現黃金交叉")
        XCTAssertFalse(death.isEmpty, "下跌段應出現死亡交叉")
    }

    // MARK: - RSI / VWAP / 波動率

    func test_RSI_全數上漲時應接近100() {
        let closes = (1...30).map { Double($0) }
        let result = Indicators.rsi(closes: closes)
        XCTAssertEqual(result.last!!, 100, accuracy: 0.001)
    }

    func test_VWAP_以成交量加權計算() {
        let calendar = TWSEDateUtility.taipeiCalendar
        let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let quotes = [
            DailyQuote(date: base, open: 10, high: 10, low: 10, close: 10, change: 0, volumeLots: 100, turnoverCount: 1),
            DailyQuote(date: calendar.date(byAdding: .day, value: 1, to: base)!,
                       open: 20, high: 20, low: 20, close: 20, change: 10, volumeLots: 300, turnoverCount: 1)
        ]

        // (10*100 + 20*300) / 400 = 17.5
        XCTAssertEqual(Indicators.vwap(quotes: quotes, period: 2)!, 17.5, accuracy: 0.0001)
    }

    func test_年化波動率_固定漲幅時趨近於零() {
        let closes = (0..<40).map { 100 * pow(1.01, Double($0)) }
        let volatility = Indicators.annualizedVolatility(closes: closes)!
        XCTAssertLessThan(volatility, 0.001, "等比成長的報酬率標準差應接近 0")
    }
}
