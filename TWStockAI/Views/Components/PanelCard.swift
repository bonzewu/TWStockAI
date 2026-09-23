import SwiftUI

/// 儀表板面板外框：編號徽章 + 標題 + 副標 + 內容。
struct PanelCard<Content: View>: View {

    let index: Int?
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(index: Int? = nil, title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.index = index
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Theme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let index {
                Text(String(format: "%02d", index))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            if let subtitle {
                Text("｜\(subtitle)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
            }

            Spacer()
        }
    }
}
