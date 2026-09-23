import XCTest
@testable import TWStockAI

/// 攔截網路請求的假 URLProtocol，讓功能測試不需連外。
final class StubURLProtocol: URLProtocol {

    /// 由測試設定：輸入請求，輸出 (狀態碼, 回應內容)。
    static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }

    /// 建立使用本攔截器的 URLSession。
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

/// 資料抓取流程的功能測試。
final class MarketDataServiceTests: XCTestCase {

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    /// 組出一份符合 TWSE 格式的假日 K 回應。
    private func stockDayPayload(month: Int, days: Int) -> Data {
        let rows = (1...days).map { day -> String in
            let price = 100 + Double(day) + Double(month)
            let date = "115/\(String(format: "%02d", month))/\(String(format: "%02d", day))"
            let open = String(format: "%.2f", price - 1)
            let high = String(format: "%.2f", price + 2)
            let low = String(format: "%.2f", price - 2)
            let close = String(format: "%.2f", price)
            return "[\"\(date)\",\"10,000,000\",\"1,000,000,000\",\"\(open)\",\"\(high)\","
                + "\"\(low)\",\"\(close)\",\"+1.00\",\"5,000\",\"\"]"
        }.joined(separator: ",")

        let json = """
        {"stat":"OK","date":"2026\(String(format: "%02d", month))01",
         "title":"115年\(String(format: "%02d", month))月 2330 台積電 各日成交資訊",
         "fields":["日期","成交股數","成交金額","開盤價","最高價","最低價","收盤價","漲跌價差","成交筆數","註記"],
         "data":[\(rows)]}
        """
        return Data(json.utf8)
    }

    /// 組出一份符合 TWSE 格式的假三大法人回應。
    private func institutionalPayload() -> Data {
        let json = """
        {"stat":"OK","fields":["證券代號","證券名稱","外陸資買賣超股數(不含外資自營商)",
         "外資自營商買賣超股數","投信買賣超股數","自營商買賣超股數","三大法人買賣超股數"],
         "data":[["2330","台積電","6,039,352","0","478,401","1,361,432","7,879,185"],
                 ["2317","鴻海","-1,000,000","0","0","0","-1,000,000"]]}
        """
        return Data(json.utf8)
    }

    func test_查詢流程_可組出完整資料集並換算單位() async throws {
        StubURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("STOCK_DAY") {
                // 由 query 取出月份，讓每個月回傳不同資料
                let month = Int(url.split(separator: "=").dropFirst().first?.prefix(6).suffix(2) ?? "01") ?? 1
                return (200, self.stockDayPayload(month: month, days: 20))
            }
            if url.contains("T86") {
                return (200, self.institutionalPayload())
            }
            return (404, Data())
        }

        let session = StubURLProtocol.makeSession()
        let service = MarketDataService(twse: TWSEClient(session: session), tpex: TPExClient(session: session))
        let dataset = try await service.loadDataset(code: "2330", targetTradingDays: 60, institutionalDays: 3)

        XCTAssertEqual(dataset.identity.code, "2330")
        XCTAssertEqual(dataset.identity.market, .listed)
        XCTAssertEqual(dataset.quotes.count, 60)
        XCTAssertEqual(dataset.badge.priceSource, "日K TWSE")

        // 成交股數 10,000,000 應換算為 10,000 張
        XCTAssertEqual(dataset.quotes.last!.volumeLots, 10_000, accuracy: 0.001)

        // 外資 = 外陸資 + 外資自營商 = 6,039,352 股 → 6,039.352 張
        let flow = try XCTUnwrap(dataset.institutional.last)
        XCTAssertEqual(flow.foreign, 6_039.352, accuracy: 0.001)
        XCTAssertEqual(flow.trust, 478.401, accuracy: 0.001)
        XCTAssertEqual(flow.total, flow.foreign + flow.trust + flow.dealer, accuracy: 0.001)
    }

    func test_TWSE查無資料時_自動改用TPEx備援() async throws {
        StubURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("STOCK_DAY") {
                return (200, Data("""
                {"stat":"很抱歉，沒有符合條件的資料!"}
                """.utf8))
            }
            if url.contains("tradingStock") {
                let rows = (1...25).map { day in
                    """
                    ["115/09/\(String(format: "%02d", day))","12,770","12,430,205","908.00","998.00","908.00","994.00","82.00","31,831"]
                    """
                }.joined(separator: ",")
                return (200, Data("""
                {"tables":[{"title":"個股日成交資訊","subtitle":"6488 環球晶 115年09月","data":[\(rows)]}]}
                """.utf8))
            }
            return (404, Data())
        }

        let session = StubURLProtocol.makeSession()
        let service = MarketDataService(twse: TWSEClient(session: session), tpex: TPExClient(session: session))
        let dataset = try await service.loadDataset(code: "6488", targetTradingDays: 25, institutionalDays: 2)

        XCTAssertEqual(dataset.identity.market, .otc)
        XCTAssertEqual(dataset.identity.name, "環球晶")
        XCTAssertEqual(dataset.badge.priceSource, "日K TPEx")
        XCTAssertTrue(dataset.institutional.isEmpty, "上櫃股票不應取得 TWSE 法人資料")

        // TPEx 的成交仟股即為張數
        XCTAssertEqual(dataset.quotes.last!.volumeLots, 12_770, accuracy: 0.001)
    }

    func test_兩個來源皆無資料時_丟出空資料集錯誤而非產生模擬值() async {
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"stat":"很抱歉，沒有符合條件的資料!"}"#.utf8))
        }

        let session = StubURLProtocol.makeSession()
        let service = MarketDataService(twse: TWSEClient(session: session), tpex: TPExClient(session: session))

        do {
            _ = try await service.loadDataset(code: "0000", targetTradingDays: 30, institutionalDays: 1)
            XCTFail("應該丟出 emptyDataset 錯誤")
        } catch let error as MarketDataError {
            guard case .emptyDataset = error else {
                return XCTFail("錯誤型別不符：\(error)")
            }
        } catch {
            XCTFail("非預期的錯誤：\(error)")
        }
    }

    func test_代號格式錯誤時立即回報而不發出請求() async {
        StubURLProtocol.handler = { _ in
            XCTFail("代號格式錯誤時不應發出任何網路請求")
            return (200, Data())
        }

        let session = StubURLProtocol.makeSession()
        let service = MarketDataService(twse: TWSEClient(session: session), tpex: TPExClient(session: session))

        do {
            _ = try await service.loadDataset(code: "12")
            XCTFail("應該丟出 invalidCode 錯誤")
        } catch let error as MarketDataError {
            guard case .invalidCode = error else {
                return XCTFail("錯誤型別不符：\(error)")
            }
        } catch {
            XCTFail("非預期的錯誤：\(error)")
        }
    }

    func test_伺服器回應500時_轉為可讀的錯誤訊息() async {
        StubURLProtocol.handler = { _ in (500, Data()) }

        let session = StubURLProtocol.makeSession()
        let service = MarketDataService(twse: TWSEClient(session: session), tpex: TPExClient(session: session))

        do {
            _ = try await service.loadDataset(code: "2330", targetTradingDays: 30, institutionalDays: 1)
            XCTFail("應該丟出 badResponse 錯誤")
        } catch let error as MarketDataError {
            XCTAssertTrue(error.errorDescription?.contains("500") ?? false)
        } catch {
            XCTFail("非預期的錯誤：\(error)")
        }
    }
}
