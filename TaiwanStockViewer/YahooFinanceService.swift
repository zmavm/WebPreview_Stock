import Foundation

protocol StockDataProviding {
    func candles(symbol: String, period: ChartPeriod) async throws -> [StockCandle]
}

enum StockServiceError: LocalizedError {
    case invalidSymbol, unavailable
    var errorDescription: String? {
        switch self { case .invalidSymbol: return "找不到此股票代碼，請確認格式，例如：0050.TW。"; case .unavailable: return "目前無法取得市場資料，請稍後再試。" }
    }
}

struct YahooFinanceService: StockDataProviding {
    func candles(symbol: String, period: ChartPeriod) async throws -> [StockCandle] {
        let safeSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(safeSymbol)?range=\(period.apiRange)&interval=1d&events=history") else { throw StockServiceError.invalidSymbol }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw StockServiceError.unavailable }
        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let result = decoded.chart.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators.quote.first else { throw StockServiceError.invalidSymbol }
        let rows = zip(timestamps.indices, timestamps).compactMap { index, timestamp -> StockCandle? in
            guard let open = quote.open[index], let high = quote.high[index], let low = quote.low[index], let close = quote.close[index], let volume = quote.volume[index] else { return nil }
            return StockCandle(date: Date(timeIntervalSince1970: timestamp), open: open, high: high, low: low, close: close, volume: volume)
        }
        guard !rows.isEmpty else { throw StockServiceError.invalidSymbol }
        return rows
    }
}

private struct ChartResponse: Decodable { let chart: Chart; struct Chart: Decodable { let result: [Result]? }; struct Result: Decodable { let timestamp: [TimeInterval]?; let indicators: Indicators }; struct Indicators: Decodable { let quote: [Quote] }; struct Quote: Decodable { let open, high, low, close, volume: [Double?] } }
