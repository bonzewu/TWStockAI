import SwiftUI

/// 原始資料表：日 K 與各項指標的逐日明細。
struct RawDataTableView: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    /// 搜尋字串（可用日期篩選）。
    @State private var searchText = ""
    /// 是否由新到舊排序。
    @State private var isDescending = true

    private var rows: [Int] {
        let indices = dataset.quotes.indices.filter { index in
            guard !searchText.isEmpty else { return true }
            return DateFormatter.twDate.string(from: dataset.quotes[index].date).contains(searchText)
        }
        return isDescending ? indices.reversed() : Array(indices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            ScrollView([.horizontal, .vertical]) {
                RawDataTable(dataset: dataset, analysis: analysis, rowIndices: rows)
            }
            .frame(maxHeight: 560)
        }
        .padding(14)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("原始資料表（\(dataset.quotes.count) 個交易日）")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            TextField("以日期篩選，例如 2026-09", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 200)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.panelElevated)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            Button {
                isDescending.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isDescending ? "arrow.down" : "arrow.up")
                        .font(.system(size: 10))
                    Text(isDescending ? "由新到舊" : "由舊到新")
                        .font(.system(size: 11))
                }
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.panelElevated)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("共 \(rows.count) 筆")
                .font(.system(size: 11))
                .foregroundColor(Theme.textMuted)
        }
    }
}

/// 資料表本體：不含捲動容器，方便單獨渲染與測試。
struct RawDataTable: View {

    let dataset: StockDataset
    let analysis: AnalysisResult
    let rowIndices: [Int]

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            ForEach(rowIndices, id: \.self) { index in
                dataRow(index: index)
            }
        }
    }

    private let columns: [(title: String, width: CGFloat)] = [
        ("日期", 92), ("開盤", 64), ("最高", 64), ("最低", 64), ("收盤", 64),
        ("漲跌", 64), ("漲跌幅", 68), ("成交量(張)", 84), ("成交筆數", 76),
        ("MA5", 64), ("MA10", 64), ("MA20", 64), ("MA60", 64),
        ("K", 56), ("D", 56), ("DIF", 60), ("MACD", 60), ("OSC", 60)
    ]

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.title) { column in
                Text(column.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: column.width, alignment: .trailing)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 3)
            }
        }
        .background(Theme.panelElevated)
    }

    private func dataRow(index: Int) -> some View {
        let quote = dataset.quotes[index]
        let kd = analysis.kd[index]
        let macd = analysis.macd[index]
        let changeTint = Theme.changeColor(quote.change)

        /// 將 Optional 指標值轉為顯示字串。
        func text(_ value: Double?, digits: Int = 2) -> String {
            value.map { String(format: "%.\(digits)f", $0) } ?? "—"
        }

        return HStack(spacing: 0) {
            cell(DateFormatter.twDate.string(from: quote.date), width: columns[0].width, tint: Theme.textSecondary)
            cell(Format.price(quote.open), width: columns[1].width, tint: Theme.textPrimary)
            cell(Format.price(quote.high), width: columns[2].width, tint: Theme.bullish)
            cell(Format.price(quote.low), width: columns[3].width, tint: Theme.bearish)
            cell(Format.price(quote.close), width: columns[4].width, tint: changeTint)
            cell(Format.signedPrice(quote.change), width: columns[5].width, tint: changeTint)
            cell(Format.percent(quote.changePercent), width: columns[6].width, tint: changeTint)
            cell(Format.integer(quote.volumeLots), width: columns[7].width, tint: Theme.textPrimary)
            cell(Format.integer(Double(quote.turnoverCount)), width: columns[8].width, tint: Theme.textSecondary)
            cell(text(analysis.ma5[index]), width: columns[9].width, tint: Theme.ma5)
            cell(text(analysis.ma10[index]), width: columns[10].width, tint: Theme.ma10)
            cell(text(analysis.ma20[index]), width: columns[11].width, tint: Theme.ma20)
            cell(text(analysis.ma60[index]), width: columns[12].width, tint: Theme.ma60)
            cell(text(kd?.k, digits: 1), width: columns[13].width, tint: Theme.kLine)
            cell(text(kd?.d, digits: 1), width: columns[14].width, tint: Theme.dLine)
            cell(text(macd?.dif), width: columns[15].width, tint: Theme.difLine)
            cell(text(macd?.macd), width: columns[16].width, tint: Theme.macdLine)
            cell(text(macd?.osc), width: columns[17].width,
                 tint: (macd?.osc ?? 0) >= 0 ? Theme.bullish : Theme.bearish)
        }
        .background(index % 2 == 0 ? Color.clear : Theme.panelElevated.opacity(0.35))
    }

    private func cell(_ text: String, width: CGFloat, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(tint)
            .frame(width: width, alignment: .trailing)
            .padding(.vertical, 4)
            .padding(.horizontal, 3)
    }
}
