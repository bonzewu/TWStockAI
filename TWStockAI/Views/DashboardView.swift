import SwiftUI

/// AI 儀表板：依參考設計排列 18 個分析面板。
struct DashboardView: View {

    let dataset: StockDataset
    let analysis: AnalysisResult

    var body: some View {
        VStack(spacing: 12) {
            // 第一列：主 K 線圖 + 決策核心 + 多維度 + 熱區 + 風險雷達
            HStack(alignment: .top, spacing: 12) {
                MainChartPanel(dataset: dataset, analysis: analysis)
                    .frame(minWidth: 420, maxWidth: .infinity)
                DecisionCorePanel(analysis: analysis)
                    .frame(width: 270)
                MultiDimensionPanel(analysis: analysis)
                    .frame(width: 250)
                HeatMapPanel(analysis: analysis)
                    .frame(width: 250)
                RiskRadarPanel(analysis: analysis)
                    .frame(width: 250)
            }

            // 第二列：預測路徑 + 成本結構 + 法人行為 + 隔日沖風險
            HStack(alignment: .top, spacing: 12) {
                ForecastPanel(analysis: analysis)
                    .frame(maxWidth: .infinity)
                CostStructurePanel(dataset: dataset, analysis: analysis)
                    .frame(maxWidth: .infinity)
                InstitutionalPanel(analysis: analysis)
                    .frame(maxWidth: .infinity)
                DayTradeRiskPanel(analysis: analysis)
                    .frame(width: 290)
            }

            // 第三列：多空能量 + 健康度 + 信號 + 情緒 + 信心 + 籌碼異動
            HStack(alignment: .top, spacing: 12) {
                EnergyPanel(analysis: analysis)
                    .frame(width: 220)
                HealthPanel(analysis: analysis)
                    .frame(minWidth: 340)
                SignalPanel(analysis: analysis)
                    .frame(width: 230)
                SentimentPanel(analysis: analysis)
                    .frame(width: 280)
                ConfidencePanel(analysis: analysis)
                    .frame(width: 260)
                ChipChangePanel(dataset: dataset, analysis: analysis)
                    .frame(maxWidth: .infinity)
            }

            // 第四列：買賣力 + 多空強度 + 總評判
            HStack(alignment: .top, spacing: 12) {
                BuyPowerPanel(dataset: dataset, analysis: analysis)
                    .frame(maxWidth: .infinity)
                StrengthPanel(analysis: analysis)
                    .frame(maxWidth: .infinity)
                VerdictPanel(analysis: analysis)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
