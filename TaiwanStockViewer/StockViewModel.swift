import Foundation

@MainActor
final class StockViewModel: ObservableObject {
    @Published var symbol = "0050.TW"
    @Published var period: ChartPeriod = .sixMonths
    @Published private(set) var candles: [StockCandle] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private let service: StockDataProviding

    init(service: StockDataProviding = YahooFinanceService()) { self.service = service }

    var snapshot: QuoteSnapshot? { guard let latest = candles.last else { return nil }; return QuoteSnapshot(latest: latest, previousClose: candles.dropLast().last?.close ?? latest.open) }
    func movingAverage(_ days: Int) -> [Double?] { candles.indices.map { i in i + 1 < days ? nil : candles[(i - days + 1)...i].map(\.close).reduce(0, +) / Double(days) } }

    func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { candles = try await service.candles(symbol: normalizedSymbol, period: period) }
        catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "讀取資料時發生錯誤。" }
    }

    var normalizedSymbol: String {
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return upper.contains(".") ? upper : "\(upper).TW"
    }

    var analysis: [AnalysisCard] {
        guard let quote = snapshot else { return [] }
        let price = quote.latest.close
        let ma5 = movingAverage(5).last ?? price, ma20 = movingAverage(20).last ?? price, ma60 = movingAverage(60).last ?? price
        let trend: AnalysisCard = price > ma5 && ma5 > ma20
          ? .init(title: "趨勢分析：多頭偏強", detail: "最新價站上 MA5 與 MA20，短中期趨勢偏強。", colorName: "blue")
          : price < ma5 && ma5 < ma20 ? .init(title: "趨勢分析：空頭修整", detail: "價格低於短期均線，留意 MA60 支撐。", colorName: "red")
          : .init(title: "趨勢分析：高檔震盪", detail: "價格與短中期均線交錯，等待方向突破。", colorName: "blue")
        let alignment = ma5 >= ma20 && ma20 >= ma60 ? "多頭排列" : ma5 <= ma20 && ma20 <= ma60 ? "空頭排列" : "均線糾結整理"
        let advice = price >= ma5 ? "短線沿 MA5 順勢操作" : "等待止跌築底訊號"
        return [trend, .init(title: "均線型態：\(alignment)", detail: "MA5 \(ma5.money)・MA20 \(ma20.money)・MA60 \(ma60.money)", colorName: "purple"), .init(title: advice, detail: "技術指標僅供參考，請搭配風險控管與自行判斷。", colorName: "green")]
    }
}

extension Double { var money: String { String(format: "%.2f", self) } }
