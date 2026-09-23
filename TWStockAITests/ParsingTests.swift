import XCTest
@testable import TWStockAI

/// 交易所資料解析的單元測試。
final class ParsingTests: XCTestCase {

    func test_民國年字串_可轉為正確的西元日期() {
        let date = TWSEDateUtility.date(fromROC: "115/09/18")
        XCTAssertNotNil(date)

        let components = TWSEDateUtility.taipeiCalendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 18)
    }

    func test_民國年中文格式_同樣可解析() {
        let date = TWSEDateUtility.date(fromROC: "115年09月18日")
        XCTAssertEqual(DateFormatter.twDate.string(from: date!), "2026-09-18")
    }

    func test_民國年字串_格式錯誤時回傳nil() {
        XCTAssertNil(TWSEDateUtility.date(fromROC: "不是日期"))
        XCTAssertNil(TWSEDateUtility.date(fromROC: "115/09"))
    }

    func test_數值解析_去除千分位() {
        XCTAssertEqual(Parsing.number("31,855,287"), 31_855_287)
        XCTAssertEqual(Parsing.number("2,440.00"), 2440)
        XCTAssertNil(Parsing.number(""))
        XCTAssertNil(Parsing.number("--"))
    }

    func test_漲跌欄位解析_支援正負號與X前綴() {
        XCTAssertEqual(Parsing.signedNumber("+35.00"), 35)
        XCTAssertEqual(Parsing.signedNumber("-55.00"), -55)
        XCTAssertEqual(Parsing.signedNumber("X0.00"), 0)
        XCTAssertNil(Parsing.signedNumber("--"))
    }

    func test_查詢日期字串_格式為yyyyMMdd() {
        let date = TWSEDateUtility.taipeiCalendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        XCTAssertEqual(TWSEDateUtility.queryString(from: date), "20260901")
        XCTAssertEqual(TWSEDateUtility.tpexQueryString(from: date), "2026/09/01")
    }

    func test_月份錨點_由舊到新且數量正確() {
        let reference = TWSEDateUtility.taipeiCalendar.date(from: DateComponents(year: 2026, month: 9, day: 23))!
        let anchors = TWSEDateUtility.recentMonthAnchors(count: 5, from: reference)

        XCTAssertEqual(anchors.count, 5)
        XCTAssertEqual(TWSEDateUtility.queryString(from: anchors.first!), "20260501")
        XCTAssertEqual(TWSEDateUtility.queryString(from: anchors.last!), "20260901")
    }
}
