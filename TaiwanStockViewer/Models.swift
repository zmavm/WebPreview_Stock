import Foundation

struct StockCandle: Identifiable, Equatable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    var id: Date { date }
}

enum ChartPeriod: String, CaseIterable, Identifiable {
    case month = "1 個月", threeMonths = "3 個月", sixMonths = "6 個月", year = "1 年", twoYears = "2 年", fiveYears = "5 年"
    var id: String { rawValue }
    var apiRange: String { ["1 個月": "1mo", "3 個月": "3mo", "6 個月": "6mo", "1 年": "1y", "2 年": "2y", "5 年": "5y"][rawValue]! }
}

struct QuoteSnapshot {
    let latest: StockCandle
    let previousClose: Double
    var change: Double { latest.close - previousClose }
    var changePercent: Double { previousClose == 0 ? 0 : change / previousClose * 100 }
}

struct AnalysisCard: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let colorName: String
}
