import SwiftUI
import Charts

struct StockDashboardView: View {
    @StateObject private var model = StockViewModel()
    @State private var isRefreshing = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    controls
                    if model.isLoading { ProgressView("正在讀取市場資料…").frame(maxWidth: .infinity, minHeight: 260) }
                    else if let message = model.errorMessage { ContentUnavailableView("無法載入資料", systemImage: "exclamationmark.triangle", description: Text(message)) }
                    else if let quote = model.snapshot { dashboard(quote) }
                }.padding()
            }
            .navigationTitle("股票看盤儀表板")
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack { TextField("代碼（0050.TW）", text: $model.symbol).textInputAutocapitalization(.characters).autocorrectionDisabled().textFieldStyle(.roundedBorder); Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderedProminent) }
            Picker("時間範圍", selection: $model.period) { ForEach(ChartPeriod.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).onChange(of: model.period) { _, _ in Task { await model.load() } }
            HStack(spacing: 6) { Circle().fill(.green).frame(width: 8, height: 8); Text("台北時間 \(Date.now.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder private func dashboard(_ quote: QuoteSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            MetricCard(title: "最新收盤價", value: quote.latest.close.money, delta: String(format: "%+.2f (%+.2f%%)", quote.change, quote.changePercent))
            MetricCard(title: "開盤價", value: quote.latest.open.money)
            MetricCard(title: "最高價", value: quote.latest.high.money)
            MetricCard(title: "最低價", value: quote.latest.low.money)
            MetricCard(title: "成交量（張）", value: "\(Int(quote.latest.volume / 1_000).formatted())")
        }
        StockChart(candles: model.candles, ma5: model.movingAverage(5), ma20: model.movingAverage(20), ma60: model.movingAverage(60)).frame(height: 410)
        ForEach(model.analysis) { card in AnalysisCardView(card: card) }
        Text("資料延遲或缺漏時，以市場正式公告為準；本 App 不構成投資建議。 ").font(.footnote).foregroundStyle(.secondary)
    }
}

private struct MetricCard: View { let title: String; let value: String; var delta: String? = nil; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title3.weight(.semibold)); if let delta { Text(delta).font(.caption).foregroundStyle(delta.hasPrefix("+") ? .red : .green) } }.frame(maxWidth: .infinity, minHeight: 75, alignment: .leading).padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
private struct AnalysisCardView: View { let card: AnalysisCard; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(card.title).font(.subheadline.weight(.bold)); Text(card.detail).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding().overlay(alignment: .leading) { Capsule().fill(Color(card.colorName)).frame(width: 4) }.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
