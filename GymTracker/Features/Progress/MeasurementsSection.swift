import SwiftUI
import SwiftData
import Charts

/// "Measurements" section for the Progress tab: latest value per tracked
/// body site, with per-site history charts and logging.
struct MeasurementsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var entries: [BodyMeasurement]

    @State private var showingLogSheet = false

    /// Metrics that have at least one entry, in canonical order.
    private var trackedMetrics: [BodyMetric] {
        BodyMetric.allCases.filter { metric in
            entries.contains { $0.metric == metric }
        }
    }

    var body: some View {
        Section("Measurements") {
            if trackedMetrics.isEmpty {
                HStack {
                    Text("Track waist, arms and more alongside the scale.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    logButton
                }
            } else {
                ForEach(trackedMetrics) { metric in
                    NavigationLink {
                        MeasurementHistoryView(metric: metric)
                    } label: {
                        metricRow(metric)
                    }
                }
                HStack {
                    Spacer()
                    logButton
                }
            }
        }
        .sheet(isPresented: $showingLogSheet) {
            MeasurementLogSheet()
        }
    }

    private var logButton: some View {
        Button("Log") {
            showingLogSheet = true
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func metricRow(_ metric: BodyMetric) -> some View {
        let history = entries.filter { $0.metric == metric }
        let latest = history.first
        let previous = history.dropFirst().first
        return HStack {
            Text(metric.displayName)
                .font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(MeasurementUnit.format(latest?.valueCm ?? 0, settings: settings))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                if let latest, let previous {
                    let delta = latest.valueCm - previous.valueCm
                    Text("\(delta >= 0 ? "+" : "")\(MeasurementUnit.format(delta, settings: settings))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

/// Display conversion for lengths: cm canonically, inches when the app is
/// set to pounds.
@MainActor
enum MeasurementUnit {
    static func usesInches(_ settings: AppSettings) -> Bool {
        settings.weightUnit == .lb
    }

    static func symbol(_ settings: AppSettings) -> String {
        usesInches(settings) ? "in" : "cm"
    }

    static func display(_ cm: Double, settings: AppSettings) -> Double {
        usesInches(settings) ? cm / 2.54 : cm
    }

    static func toCm(_ value: Double, settings: AppSettings) -> Double {
        usesInches(settings) ? value * 2.54 : value
    }

    static func format(_ cm: Double, settings: AppSettings) -> String {
        let value = display(cm, settings: settings)
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(symbol(settings))"
    }
}

struct MeasurementHistoryView: View {
    let metric: BodyMetric

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var allEntries: [BodyMeasurement]

    @State private var showingLogSheet = false

    private var entries: [BodyMeasurement] {
        allEntries.filter { $0.metric == metric }
    }

    var body: some View {
        List {
            if entries.count >= 2 {
                Section {
                    let points = entries.sorted { $0.date < $1.date }
                    let values = points.map { MeasurementUnit.display($0.valueCm, settings: settings) }
                    let lower = (values.min() ?? 0) * 0.98
                    let upper = (values.max() ?? 1) * 1.02
                    Chart(points) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Value", MeasurementUnit.display(entry.valueCm, settings: settings))
                        )
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Value", MeasurementUnit.display(entry.valueCm, settings: settings))
                        )
                    }
                    .chartYScale(domain: lower...upper)
                    .frame(height: 180)
                    .padding(.vertical, 4)
                }
            }

            Section {
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.date.formatted(.dateTime.weekday().day().month().year()))
                            .font(.subheadline)
                        Spacer()
                        Text(MeasurementUnit.format(entry.valueCm, settings: settings))
                            .font(.subheadline.monospacedDigit())
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(entries[index])
                    }
                    try? context.save()
                }
            }
        }
        .navigationTitle(metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log") {
                    showingLogSheet = true
                }
            }
        }
        .sheet(isPresented: $showingLogSheet) {
            MeasurementLogSheet(initialMetric: metric)
        }
    }
}

struct MeasurementLogSheet: View {
    var initialMetric: BodyMetric = .waist

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var metric: BodyMetric = .waist
    @State private var valueText = ""
    @State private var date = Date.now

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var entries: [BodyMeasurement]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Measurement", selection: $metric) {
                    ForEach(BodyMetric.allCases) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                HStack {
                    Text("Value")
                    Spacer()
                    TextField("0", text: $valueText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text(MeasurementUnit.symbol(settings))
                        .foregroundStyle(.secondary)
                }
                DatePicker("Date", selection: $date, in: ...Date.now)
            }
            .navigationTitle("Log Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(Format.parseWeight(valueText) <= 0)
                }
            }
            .onAppear {
                metric = initialMetric
                prefill()
            }
            .onChange(of: metric) { _, _ in
                prefill()
            }
        }
        .presentationDetents([.medium])
    }

    private func prefill() {
        guard let last = entries.first(where: { $0.metric == metric }) else {
            valueText = ""
            return
        }
        // Round to one decimal — a cm value logged in kg-mode converts to an
        // unround inch value, and a 15-digit prefill helps nobody.
        let display = MeasurementUnit.display(last.valueCm, settings: settings)
        valueText = Format.editableWeight((display * 10).rounded() / 10)
    }

    private func save() {
        let value = Format.parseWeight(valueText)
        guard value > 0 else { return }
        let entry = BodyMeasurement(
            date: date,
            metric: metric,
            valueCm: MeasurementUnit.toCm(value, settings: settings)
        )
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}
