import SwiftUI

/// 起始畫面：說明文字、大型輸入框與常用個股快速選擇。
struct WelcomeView: View {

    @EnvironmentObject private var state: AppState
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 40)

                Text("台股 AI 主力行為判讀系統")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(Theme.accent)

                Text("輸入股票代號後，系統會抓取近 98 個交易日的真實資料（TWSE 優先、TPEx 備援），\n依該股票即時產生 18 面板圖表與四大任務報告。")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                HStack(spacing: 14) {
                    TextField("例如 2330", text: $state.codeInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 320, height: 66)
                        .background(Theme.panelElevated)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($isFocused)
                        .onSubmit { Task { await state.analyze() } }

                    Button {
                        Task { await state.analyze() }
                    } label: {
                        Text("開始分析")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 150, height: 66)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isLoading)
                }

                VStack(spacing: 10) {
                    Text("快速選擇：")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)

                    quickPickGrid
                }

                Text("上市股票由 TWSE 取得；上櫃股票（TWSE 無資料）將自動改用 TPEx。\n雙來源皆失敗時不會產生任何模擬數據。")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Spacer(minLength: 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .background(Theme.background)
        .onAppear { isFocused = true }
    }

    private var quickPickGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(132), spacing: 8), count: 6), spacing: 8) {
            ForEach(state.quickPicks, id: \.code) { pick in
                Button {
                    Task { await state.analyze(code: pick.code) }
                } label: {
                    Text("\(pick.code) \(pick.name)")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.panelElevated)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 860)
    }
}
