import XCTest
@testable import TWStockAI

/// AI 分析引擎的功能測試：驗證輸出結構完整、數值落在合理範圍。
final class AIAnalyzerTests: XCTestCase {

    /// 以指定收盤價序列組出測試資料集。
    private func makeDataset(closes: [Double], withInstitutional: Bool = true) -> StockDataset {
        let calendar = TWSEDateUtility.taipeiCalendar
        let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!

        let quotes = closes.enumerated().map { index, close -> DailyQuote in
            let date = calendar.date(byAdding: .day, value: index, to: base)!
            return DailyQuote(
                date: date,
                open: close - 1, high: close + 3, low: close - 3, close: close,
                change: index == 0 ? 0 : close - closes[index - 1],
                volumeLots: 2_000 + Double(index % 7) * 300,
                turnoverCount: 1_200 + index
            )
        }

        let flows = withInstitutional
            ? quotes.suffix(12).enumerated().map { index, quote in
                InstitutionalFlow(date: quote.date,
                                  foreign: Double((index % 3) - 1) * 500,
                                  trust: 120, dealer: -60)
            }
            : []

        return StockDataset(
            identity: StockIdentity(code: "9999", name: "測試股", market: .listed),
            quotes: quotes,
            institutional: Array(flows),
            badge: DataSourceBadge(priceSource: "日K TWSE", institutionalSource: "法人 TWSE", marginSource: "融資券 TWSE")
        )
    }

    func test_資料不足20日時不產生分析結果() {
        let dataset = makeDataset(closes: (1...10).map { Double($0) })
        XCTAssertNil(AIAnalyzer.analyze(dataset: dataset))
    }

    func test_完整資料能產生所有面板所需欄位() throws {
        let closes: [Double] = (1...98).map { index in
            let base = 100 + Double(index) * 0.8
            return base + sin(Double(index) / 4) * 3
        }
        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: closes)))

        XCTAssertGreaterThan(analysis.mainForceCost, 0)
        XCTAssertGreaterThan(analysis.pressureZone, analysis.supportZone)
        XCTAssertEqual(analysis.healthMetrics.count, 5)
        XCTAssertEqual(analysis.dayTradeRiskMetrics.count, 5)
        XCTAssertEqual(analysis.confidenceMetrics.count, 5)
        XCTAssertEqual(analysis.radar.ordered.count, 6)
        XCTAssertEqual(analysis.riskRadar.count, 5)
        XCTAssertEqual(analysis.forecast.count, 4)
        XCTAssertFalse(analysis.heatCells.isEmpty)
        XCTAssertEqual(analysis.heatLegend.count, 5)
        XCTAssertFalse(analysis.aiConclusion.isEmpty)
        XCTAssertFalse(analysis.mainForceVerdict.isEmpty)
    }

    func test_所有百分比型指標皆落在0到100之間() throws {
        let closes: [Double] = (1...98).map { index in
            let base = 250 - Double(index) * 0.9
            return base + cos(Double(index) / 5) * 4
        }
        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: closes)))

        // 分段收集，避免單一運算式過長導致編譯器型別推導變慢
        var percentages: [Double] = analysis.radar.availableValues
        percentages += analysis.riskRadar.compactMap(\.value)
        percentages += analysis.healthMetrics.compactMap(\.value)
        percentages += analysis.dayTradeRiskMetrics.compactMap(\.value)
        percentages += analysis.confidenceMetrics.compactMap(\.value)
        percentages += [analysis.overallScore, analysis.bullEnergy, analysis.bearEnergy]
        percentages += [analysis.marketSentiment, analysis.retailSentiment]
        percentages += [analysis.mainForceSentiment]
        percentages += analysis.institutionalSentiment.map { [$0] } ?? []
        percentages += [analysis.majorBuyPower, analysis.retailBuyPower, analysis.retailSellPressure]
        percentages.append(analysis.dayTradeRiskIndex)

        percentages.forEach { value in
            XCTAssertTrue((0...100).contains(value), "數值 \(value) 超出 0～100 範圍")
        }
    }

    func test_多空能量合計為百分之百() throws {
        let closes: [Double] = (1...60).map { 100 + Double($0 % 9) }
        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: closes)))
        XCTAssertEqual(analysis.bullEnergy + analysis.bearEnergy, 100, accuracy: 0.001)
    }

    func test_上漲震盪下跌機率合計為百分之百() throws {
        let closes: [Double] = (1...98).map { 180 + sin(Double($0) / 6) * 20 }
        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: closes)))
        let total = analysis.upProbability + analysis.flatProbability + analysis.downProbability
        XCTAssertEqual(total, 100, accuracy: 0.001)
    }

    func test_持續上漲時趨勢分數應明顯高於持續下跌() throws {
        let rising = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: (1...98).map { Double(100 + $0) })))
        let falling = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: (1...98).map { Double(200 - $0) })))

        XCTAssertGreaterThan(rising.radar.trend, falling.radar.trend)
        XCTAssertGreaterThan(rising.overallScore, falling.overallScore)
    }

    func test_無法人資料時相關欄位標示為無資料而非中性值() throws {
        let closes: [Double] = (1...98).map { 150 + Double($0) * 0.3 }
        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: closes, withInstitutional: false)))

        XCTAssertFalse(analysis.hasInstitutionalData)
        XCTAssertTrue(analysis.institutionalSeries.isEmpty)
        XCTAssertEqual(analysis.cumulativeNetLots, 0)

        // 法人面向不得以中性值填補
        XCTAssertNil(analysis.radar.institutional, "法人分數應為無資料")
        XCTAssertNil(analysis.institutionalSentiment, "法人情緒應為無資料")
        XCTAssertEqual(analysis.radar.availableValues.count, 5, "綜合評分應只計入五個面向")

        let institutionalSupport = try XCTUnwrap(analysis.healthMetrics.first { $0.label == "法人支撐度" })
        XCTAssertFalse(institutionalSupport.isAvailable)
        XCTAssertEqual(institutionalSupport.displayText, "無資料")

        let institutionalRisk = try XCTUnwrap(analysis.riskRadar.first { $0.label == "法人風險" })
        XCTAssertFalse(institutionalRisk.isAvailable)

        // 文字結論不得出現法人推論
        XCTAssertTrue(analysis.aiConclusion.contains("無三大法人公開資料"))
        XCTAssertFalse(analysis.aiConclusion.contains("法人近 5 日合計"))
        XCTAssertFalse(analysis.mainForceVerdict.contains("布局"))

        // 其餘分析照常運作
        XCTAssertFalse(analysis.heatCells.isEmpty)
        XCTAssertTrue((0...100).contains(analysis.overallScore))
    }

    func test_有法人資料時法人面向皆有數值() throws {
        let closes: [Double] = (1...98).map { 150 + Double($0) * 0.3 }
        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: closes)))

        XCTAssertTrue(analysis.hasInstitutionalData)
        XCTAssertNotNil(analysis.radar.institutional)
        XCTAssertNotNil(analysis.institutionalSentiment)
        XCTAssertEqual(analysis.radar.availableValues.count, 6)
        XCTAssertTrue(analysis.healthMetrics.allSatisfy(\.isAvailable))
        XCTAssertTrue(analysis.riskRadar.allSatisfy(\.isAvailable))
    }

    func test_無法人資料時籌碼分數改由價量推導且不等於固定中性值() throws {
        // 明顯的多頭與空頭走勢應得到不同的籌碼分數，證明不是固定回傳 50
        let rising: [Double] = (1...98).map { Double(100 + $0) }
        let falling: [Double] = (1...98).map { Double(200 - $0) }

        let bull = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: rising, withInstitutional: false)))
        let bear = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: falling, withInstitutional: false)))

        XCTAssertGreaterThan(bull.radar.chips, bear.radar.chips)
        XCTAssertNotEqual(bull.radar.chips, 50, accuracy: 0.001)
    }

    func test_主力成本結構分布能產生堆疊資料() {
        let closes: [Double] = (1...98).map { 120 + Double($0 % 11) * 2 }
        let dataset = makeDataset(closes: closes)
        let bands = AIAnalyzer.costStructure(quotes: dataset.quotes)

        XCTAssertFalse(bands.isEmpty)
        XCTAssertTrue(bands.allSatisfy { $0.volume >= 0 })
    }

    func test_技術警示只涵蓋近期且依日期由新到舊排序() throws {
        let closes = (1...98).map { index -> Double in
            index == 90 ? 100 : 150 + Double(index % 6)   // 第 90 日製造一次大跌
        }
        let analysis = try XCTUnwrap(AIAnalyzer.analyze(dataset: makeDataset(closes: closes)))

        XCTAssertFalse(analysis.alerts.isEmpty)
        let dates = analysis.alerts.map(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >), "警示應由新到舊排序")
    }
}
