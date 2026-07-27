import SwiftUI
import Charts

struct ExerciseChartsView: View {
    let dataPoints: [ExerciseDataPoint]

    @Environment(AppSettings.self) private var settings

    @State private var metric: Metric = .topSet
    @State private var range: ChartRange = .threeMonths

    enum Metric: String, CaseIterable, Identifiable {
        case topSet = "Top Set"
        case volume = "Volume"
        case e1rm = "Est. 1RM"

        var id: String { rawValue }
    }

    enum ChartRange: String, CaseIterable, Identifiable {
        case threeMonths = "3M"
        case year = "1Y"
        case all = "All"

        var id: String { rawValue }
    }

    private var filteredPoints: [ExerciseDataPoint] {
        guard let cutoff = cutoffDate else { return dataPoints }
        return dataPoints.filter { $0.date >= cutoff }
    }

    private var cutoffDate: Date? {
        let calendar = Calendar.current
        switch range {
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: Date.now)
        case .year: return calendar.date(byAdding: .year, value: -1, to: Date.now)
        case .all: return nil
        }
    }

    private func value(for point: ExerciseDataPoint) -> Double {
        switch metric {
        case .topSet: point.topSetWeight
        case .volume: point.totalVolume
        case .e1rm: point.bestE1RM
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            if filteredPoints.count >= 2 {
                Chart(filteredPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.rawValue, value(for: point))
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.rawValue, value(for: point))
                    )
                }
                .frame(height: 220)
            } else {
                Text("Not enough data in this range.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 220)
            }

            Picker("Range", selection: $range) {
                ForEach(ChartRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            Text("Values in \(settings.weightUnit.displayName). Completed working sets only.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}
