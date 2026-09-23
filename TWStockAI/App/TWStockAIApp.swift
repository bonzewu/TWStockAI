import SwiftUI

/// 應用程式進入點。
@main
struct TWStockAIApp: App {

    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 1180, minHeight: 760)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // 以選單與快捷鍵補強桌面體驗
            CommandGroup(replacing: .newItem) { }

            CommandMenu("查詢") {
                Button("重新分析") {
                    Task { await state.analyze(forceReload: true) }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(state.codeInput.isEmpty)

                Divider()

                Button("回到起始畫面") { state.reset() }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
