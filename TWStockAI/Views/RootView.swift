import SwiftUI

/// 根視圖：頂部狀態列 + 工具列 + 任務分頁 + 內容區。
struct RootView: View {

    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView()

                if state.hasResult {
                    ToolbarView()
                    TabBarView()
                    Divider().overlay(Theme.border)
                }

                content
            }

            if state.isLoading {
                LoadingOverlay(message: state.loadingMessage)
            }
        }
        .alert("查詢失敗", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("了解", role: .cancel) { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let dataset = state.dataset, let analysis = state.analysis {
            // 儀表板寬度大於視窗時需要水平捲動，否則兩側面板會被裁切；
            // 同時以 minWidth 讓單一圖表分頁仍能撐滿可視寬度。
            GeometryReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    Group {
                        switch state.selectedTab {
                        case .dashboard: DashboardView(dataset: dataset, analysis: analysis)
                        case .report: ReportView(dataset: dataset, analysis: analysis)
                        case .alerts: AlertsView(dataset: dataset, analysis: analysis)
                        case .kdma: KDMAChartView(dataset: dataset, analysis: analysis)
                        case .macd: MACDChartView(dataset: dataset, analysis: analysis)
                        case .raw: RawDataTableView(dataset: dataset, analysis: analysis)
                        }
                    }
                    .padding(14)
                    .frame(minWidth: proxy.size.width, alignment: .topLeading)
                }
            }
            .background(Theme.background)

            DisclaimerBar()
        } else {
            WelcomeView()
        }
    }
}

/// 載入中的遮罩。
struct LoadingOverlay: View {

    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                Text(message.isEmpty ? "資料載入中…" : message)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(28)
            .background(Theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// 底部免責聲明。
struct DisclaimerBar: View {
    var body: some View {
        HStack {
            Spacer()
            Text("本圖為 AI 技術分析整理，僅供參考，不構成投資建議。投資有風險，請審慎評估並自負盈虧。盤中數據可能即時變動，請依實際成交與官方資訊為準。")
                .font(.system(size: 10))
                .foregroundColor(Theme.textMuted)
            Spacer()
            Text("TW STOCK AI TRADING SYSTEM")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.panel)
    }
}

/// 任務分頁列。
struct TabBarView: View {

    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(WorkspaceTab.allCases) { tab in
                    Button {
                        state.selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: state.selectedTab == tab ? .semibold : .regular))
                        }
                        .foregroundColor(state.selectedTab == tab ? Theme.accent : Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(state.selectedTab == tab ? Theme.panelElevated : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(state.selectedTab == tab ? Theme.accent.opacity(0.6) : Color.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Theme.background)
    }
}
