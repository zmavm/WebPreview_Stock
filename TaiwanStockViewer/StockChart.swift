import SwiftUI
import Charts

struct StockChart: View {
    let candles: [StockCandle]
    let ma5: [Double?]
    let ma20: [Double?]
    let ma60: [Double?]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(candles.isEmpty ? "" : "K 線與均線走勢圖")").font(.headline)
            Chart {
                ForEach(candles) { candle in
                    RectangleMark(x: .value("日期", candle.date), yStart: .value("最低", candle.low), yEnd: .value("最高", candle.high))
                        .foregroundStyle(candle.close >= candle.open ? Color.red : Color.green)
                    BarMark(x: .value("日期", candle.date), yStart: .value("開盤", candle.open), yEnd: .value("收盤", candle.close), width: .ratio(0.65))
                        .foregroundStyle(candle.close >= candle.open ? Color.red : Color.green)
                }
                movingAverageMarks(values: ma5, name: "MA5", color: .blue)
                movingAverageMarks(values: ma20, name: "MA20", color: .orange)
                movingAverageMarks(values: ma60, name: "MA60", color: .purple)
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: max(candles.count / 5, 1))) { AxisGridLine(); AxisValueLabel(format: .dateTime.month().day()) } }
            .frame(height: 265)
            Divider()
            Text("成交量").font(.headline)
            Chart(candles) { candle in
                BarMark(x: .value("日期", candle.date), y: .value("成交量", candle.volume))
                    .foregroundStyle(candle.close >= candle.open ? Color.red.opacity(0.7) : Color.green.opacity(0.7))
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: max(candles.count / 5, 1))) { AxisValueLabel(format: .dateTime.month().day()) } }
            .frame(height: 90)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ChartContentBuilder
    private func movingAverageMarks(values: [Double?], name: String, color: Color) -> some ChartContent {
        ForEach(Array(zip(candles, values)), id: \.0.id) { candle, average in
            if let average {
                LineMark(x: .value("日期", candle.date), y: .value(name, average))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
            }
        }
    }
}
