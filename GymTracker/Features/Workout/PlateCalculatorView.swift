import SwiftUI

/// Shows which plates to load per side of the bar for a target weight.
struct PlateCalculatorView: View {
    let initialWeight: Double

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var weightText = ""

    private var plateSizes: [Double] {
        settings.weightUnit == .lb
            ? [45, 35, 25, 10, 5, 2.5]
            : [25, 20, 15, 10, 5, 2.5, 1.25]
    }

    private var targetWeight: Double {
        Format.parseWeight(weightText)
    }

    private var breakdown: (plates: [Double], remainder: Double)? {
        let perSide = (targetWeight - settings.barWeight) / 2
        guard perSide >= 0 else { return nil }
        var remaining = perSide
        var plates: [Double] = []
        for size in plateSizes {
            while remaining >= size - 0.001 {
                plates.append(size)
                remaining -= size
            }
        }
        return (plates, remaining)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Target weight")
                        Spacer()
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text(settings.weightUnit.displayName)
                            .foregroundStyle(.secondary)
                    }
                    Stepper(value: barWeightBinding, in: 0...60, step: 2.5) {
                        HStack {
                            Text("Bar")
                            Spacer()
                            Text(Format.weight(settings.barWeight, unit: settings.weightUnit))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Per Side") {
                    if let breakdown {
                        if breakdown.plates.isEmpty {
                            Text(targetWeight <= settings.barWeight + 0.001
                                 ? "Just the bar."
                                 : "No plates needed.")
                                .foregroundStyle(.secondary)
                        } else {
                            plateRow(breakdown.plates)
                            Text(breakdown.plates
                                .map { Format.plainWeight($0) }
                                .joined(separator: " + "))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if breakdown.remainder > 0.001 {
                            Label(
                                "\(Format.weight(breakdown.remainder, unit: settings.weightUnit)) per side can't be loaded with standard plates.",
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    } else {
                        Text("Target is below the bar weight.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if initialWeight > 0 {
                    weightText = Format.editableWeight(initialWeight)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var barWeightBinding: Binding<Double> {
        Binding(
            get: { settings.barWeight },
            set: { settings.barWeight = $0 }
        )
    }

    private func plateRow(_ plates: [Double]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                let scale = plateScale(plate)
                Text(Format.plainWeight(plate))
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 30 + 50 * scale)
                    .background(plateColor(plate), in: RoundedRectangle(cornerRadius: 6))
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func plateScale(_ plate: Double) -> Double {
        let largest = plateSizes.first ?? 1
        return plate / largest
    }

    private func plateColor(_ plate: Double) -> Color {
        // Rough IPF color coding for kg plates; graded blues for lb.
        if settings.weightUnit == .kg {
            switch plate {
            case 25: return .red
            case 20: return .blue
            case 15: return .yellow
            case 10: return .green
            case 5: return .white.opacity(0.4)
            default: return .gray
            }
        }
        switch plate {
        case 45: return .blue
        case 35: return .yellow
        case 25: return .green
        default: return .gray
        }
    }
}
