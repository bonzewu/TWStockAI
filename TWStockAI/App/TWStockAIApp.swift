import SwiftUI
import AppKit

/// 應用程式進入點。
@main
struct TWStockAIApp: App {

    @StateObject private var state = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 1280, minHeight: 800)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1720, height: 1000)
        .commands {
            // 保留系統預設的「新增視窗」（⌘N），避免關閉視窗後無法再開啟
            CommandMenu("查詢") {
                Button("重新分析") {
                    Task { await state.analyze(forceReload: true) }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(state.codeInput.isEmpty)

                Divider()

                Button("回到起始畫面") { state.reset() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}


/// 應用程式代理：處理視窗關閉後的生命週期。
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 這是單視窗工具型 App，關閉最後一個視窗時直接結束，
    /// 避免留下沒有視窗卻仍在執行的程序。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
