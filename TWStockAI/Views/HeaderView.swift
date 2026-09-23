import SwiftUI

/// 頂部狀態列：系統徽章、代號輸入、以及最新一日的行情摘要。
struct HeaderView: View {

    @EnvironmentObject private var state: AppState
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                statusBadges
                Spacer(minLength: 12)
                searchField
                if state.hasResult { summaryStrip }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.panel)

            Divider().overlay(Theme.border)
        }
    }

    // MARK: - 左側系統徽章

    private var statusBadges: some View {
        HStack(spacing: 14) {
            badge(symbol: "dot.circle.and.cursorarrow", title: "AI SCAN", subtitle: "ACTIVE", tint: Theme.bearish)
            badge(symbol: "gearshape.2.fill", title: "MAIN FORCE", subtitle: "TRACKING", tint: Theme.accent)
            badge(symbol: "chart.bar.fill", title: "MARKET", subtitle: "STATUS", tint: Theme.cyan)
            badge(symbol: "exclamationmark.triangle.fill", title: "VOLATILITY", subtitle: "ALERT", tint: Theme.bullish)
        }
    }

    private func badge(symbol: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: -1) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(tint)
        }
    }

    // MARK: - 代號輸入

    private var searchField: some View {
        HStack(spacing: 8) {
            TextField("代號", text: $state.codeInput)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 96)
                .focused($isInputFocused)
                .onSubmit { Task { await state.analyze() } }

            Button {
                Task { await state.analyze() }
            } label: {
                Text("分析")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(state.isLoading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.panelElevated)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 右側行情摘要

    @ViewBuilder
    private var summaryStrip: some View {
        if let dataset = state.dataset, let latest = dataset.latest {
            HStack(spacing: 0) {
                identityCell(dataset: dataset)
                cell(title: "今日收盤價", value: Format.price(latest.close), tint: Theme.changeColor(latest.change))
                cell(title: "今日漲跌", value: Format.signedPrice(latest.change), tint: Theme.changeColor(latest.change))
                cell(title: "今日漲幅", value: Format.percent(latest.changePercent), tint: Theme.changeColor(latest.change))
                cell(title: "成交量(張)", value: Format.integer(latest.volumeLots), tint: Theme.textPrimary)
                cell(title: "成交筆數", value: Format.integer(Double(latest.turnoverCount)), tint: Theme.textPrimary)
                cell(title: "開盤", value: Format.price(latest.open), tint: Theme.textPrimary)
                cell(title: "最高", value: Format.price(latest.high), tint: Theme.bullish)
                cell(title: "最低", value: Format.price(latest.low), tint: Theme.bearish)
                cell(title: "最新交易日", value: DateFormatter.twDate.string(from: latest.date), tint: Theme.accent)
                cell(title: "資料筆數", value: "\(dataset.quotes.count) 日", tint: Theme.accent)
            }
            .background(Theme.panelElevated)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func identityCell(dataset: StockDataset) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(dataset.identity.code)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accent)
            Text(dataset.identity.name)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(Rectangle().frame(width: 1).foregroundColor(Theme.border), alignment: .trailing)
    }

    private func cell(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(Theme.textMuted)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(tint)
        }
        .frame(minWidth: 72)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlay(Rectangle().frame(width: 1).foregroundColor(Theme.border), alignment: .trailing)
    }
}
