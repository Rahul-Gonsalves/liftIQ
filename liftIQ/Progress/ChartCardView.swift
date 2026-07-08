import SwiftUI
import Charts

// Minimal Apple-Health-style line chart card (README tokens): 2.5px stroke,
// faint gridlines, end-point dot, no fills.
struct ChartPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct ChartCardView: View {
    let title: String
    let points: [ChartPoint]
    let color: Color
    var valueLabel: (Double) -> String = { WorkoutStats.grouped($0) }
    var deltaText: String? = nil
    var deltaColor: Color = Theme.success

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(points.last.map { valueLabel($0.value) } ?? "—")
                    .font(.mono(28, .bold))
                    .foregroundStyle(.white)
                if let deltaText {
                    Text(deltaText)
                        .font(.mono(13, .semibold))
                        .foregroundStyle(deltaColor)
                }
            }
            if points.count > 1 {
                chart
            } else {
                Text("Not enough data yet")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, minHeight: 90)
            }
        }
        .card()
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
            }
            if let last = points.last {
                PointMark(x: .value("Date", last.date), y: .value("Value", last.value))
                    .foregroundStyle(color)
                    .symbolSize(40)
            }
        }
        .chartXScale(domain: (points.first?.date ?? .now)...(points.last?.date ?? .now))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.mono(10))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(Theme.gridline)
                AxisValueLabel()
                    .font(.mono(10))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .frame(height: 120)
    }
}
