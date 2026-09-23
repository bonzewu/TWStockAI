import Foundation
import SwiftUI
import os

/// 主頁籤（對應參考設計底部的四大任務分頁）。
enum WorkspaceTab: String, CaseIterable, Identifiable {
    case dashboard = "AI 儀表板"
    case report = "任務一：綜合分析報告"
    case alerts = "任務二：技術警示報告"
    case kdma = "任務三：KD + MA 圖表"
    case macd = "任務四：MACD 圖表"
    case raw = "原始資料表"

    var id: String { rawValue }

    /// 分頁圖示（SF Symbols）。
    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.3x3.fill"
        case .report: return "chart.bar.doc.horizontal"
        case .alerts: return "exclamationmark.triangle.fill"
        case .kdma: return "chart.xyaxis.line"
        case .macd: return "waveform.path.ecg"
        case .raw: return "tablecells"
        }
    }
}

/// 應用程式狀態容器：統籌查詢流程、分析結果與畫面狀態。
@MainActor
final class AppState: ObservableObject {

    // MARK: - 輸入

    @Published var codeInput: String = ""

    // MARK: - 結果

    @Published private(set) var dataset: StockDataset?
    @Published private(set) var analysis: AnalysisResult?

    // MARK: - 畫面狀態

    @Published private(set) var isLoading = false
    @Published private(set) var loadingMessage = ""
    @Published var errorMessage: String?
    @Published var selectedTab: WorkspaceTab = .dashboard
    @Published private(set) var lastUpdated: Date?

    /// 常用個股快速選單（對應參考設計的快速選擇按鈕）。
    let quickPicks: [(code: String, name: String)] = [
        ("2330", "台積電"), ("2317", "鴻海"), ("2454", "聯發科"), ("2308", "台達電"),
        ("2382", "廣達"), ("2303", "聯電"), ("2881", "富邦金"), ("2882", "國泰金"),
        ("0050", "元大台灣50"), ("3008", "大立光"), ("2412", "中華電"), ("6488", "環球晶(櫃)")
    ]

    private let service = MarketDataService()
    private let logger = Logger(subsystem: "com.bonzewu.TWStockAI", category: "AppState")

    /// 是否已有可顯示的分析結果。
    var hasResult: Bool { dataset != nil && analysis != nil }

    // MARK: - 查詢流程

    /// 依代號查詢並分析。
    /// - Parameter forceReload: 是否略過快取重新抓取。
    func analyze(code rawCode: String? = nil, forceReload: Bool = false) async {
        let code = (rawCode ?? codeInput).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            errorMessage = "請先輸入股票代號，例如 2330。"
            return
        }

        codeInput = code
        isLoading = true
        errorMessage = nil
        loadingMessage = "正在向 TWSE 取得 \(code) 的日 K 資料…"

        defer {
            isLoading = false
            loadingMessage = ""
        }

        do {
            if forceReload {
                await service.invalidateCache(code: code)
            }

            let fetched = try await service.loadDataset(code: code)
            loadingMessage = "正在計算技術指標與 AI 判讀…"

            guard let result = AIAnalyzer.analyze(dataset: fetched) else {
                errorMessage = "「\(code)」的有效交易日不足 20 日，無法產生完整分析。"
                return
            }

            dataset = fetched
            analysis = result
            lastUpdated = Date()
            logger.info("分析完成：\(code)，共 \(fetched.quotes.count) 個交易日")
        } catch {
            let message = (error as? MarketDataError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            logger.error("查詢失敗：\(code)｜\(message)")
        }
    }

    /// 清除目前結果，回到起始畫面。
    func reset() {
        dataset = nil
        analysis = nil
        errorMessage = nil
        codeInput = ""
        selectedTab = .dashboard
    }
}
