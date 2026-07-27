import SwiftUI
import SwiftData
import Charts

/// "Body Weight" section for the Progress tab: latest weight, 30-day delta,
/// trend chart, and recent entries.
struct BodyWeightSection: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \BodyWeightEntry.date, order: .reverse)
    private var entries: [BodyWeightEntry]

    @State private var showingLogSheet = false
    @State private var range: ChartRange = .threeMonths

    enum ChartRange: String, CaseIterable, Identifiable {
        case threeMonths = "3M"
        case year = "1Y"
        case all = "All"

        var id: String { rawValue }
    }

    private var unit: WeightUnit { settings.weightUnit }

    private func display(_ kg: Double) -> Double {
        kg / unit.kilogramsPerUnit
    }

    private var latestEntry: BodyWeightEntry? { entries.first }

    private var recentDelta: (value: Double, days: Int)? {
        guard let latest = latestEntry,
              let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: latest.date),
              let reference = entries.first(where: { $0.date <= cutoff })
        else { return nil }
        let days = Calendar.current.dateComponents([.day], from: reference.date, to: latest.date).day ?? 30
        return (display(latest.weightKg) - display(reference.weightKg), days)
    }

    private var chartEntries: [BodyWeightEntry] {
        let cutoff: Date?
        switch range {
        case .threeMonths: cutoff = Calendar.current.date(byAdding: .month, value: -3, to: Date.now)
        case .year: cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date.now)
        case .all: cutoff = nil
        }
        let filtered = cutoff.map { c in entries.filter { $0.date >= c } } ?? entries
        return filtered.sorted { $0.date < $1.date }
    }

    var body: some View {
        Section("Body Weight") {
            HStack {
                if let latest = latestEntry {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Format.weight(display(latest.weightKg), unit: unit))
                            .font(.title3.bold())
                        if let delta = recentDelta {
                            Text("\(delta.value >= 0 ? "+" : "")\(Format.plainWeight(delta.value)) \(unit.displayName) in \(delta.days) days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(latest.date.formatted(.dateTime.day().month()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Track your body weight alongside your lifts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Log") {
                    showingLogSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if entries.count >= 2 {
                if chartEntries.count >= 2 {
                    let values = chartEntries.map { display($0.weightKg) }
                    let lower = (values.min() ?? 0) * 0.98
                    let upper = (values.max() ?? 1) * 1.02
                    Chart(chartEntries) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", display(entry.weightKg))
                        )
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", display(entry.weightKg))
                        )
                    }
                    .chartYScale(domain: lower...upper)
                    .frame(height: 160)
                    .padding(.vertical, 4)
                } else {
                    Text("No entries in this range.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            ForEach(Array(entries.prefix(5))) { entry in
                HStack {
                    Text(entry.date.formatted(.dateTime.weekday().day().month()))
                        .font(.subheadline)
                    Spacer()
                    Text(Format.weight(display(entry.weightKg), unit: unit))
                        .font(.subheadline.monospacedDigit())
                }
            }
            .onDelete { offsets in
                let visible = Array(entries.prefix(5))
                for index in offsets {
                    context.delete(visible[index])
                }
                try? context.save()
            }
        }
        .sheet(isPresented: $showingLogSheet) {
            BodyWeightLogSheet(lastWeightKg: latestEntry?.weightKg)
        }
    }
}

struct BodyWeightLogSheet: View {
    var lastWeightKg: Double?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var weightText = ""
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text(settings.weightUnit.displayName)
                        .foregroundStyle(.secondary)
                }
                DatePicker("Date", selection: $date, in: ...Date.now)
            }
            .navigationTitle("Log Body Weight")
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
                    .disabled(Format.parseWeight(weightText) <= 0)
                }
            }
            .onAppear {
                if let lastWeightKg {
                    weightText = Format.editableWeight(lastWeightKg / settings.weightUnit.kilogramsPerUnit)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let value = Format.parseWeight(weightText)
        guard value > 0 else { return }
        let kg = value * settings.weightUnit.kilogramsPerUnit
        let entry = BodyWeightEntry(date: date, weightKg: kg)
        context.insert(entry)
        try? context.save()
        let entryDate = date
        Task {
            await HealthService.saveBodyWeight(kilograms: kg, date: entryDate)
        }
        dismiss()
    }
}
