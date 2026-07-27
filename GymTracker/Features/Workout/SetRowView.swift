import SwiftUI
import SwiftData

struct SetRowView: View {
    let set: SetEntry
    /// The corresponding set from the previous session, shown as placeholders.
    var lastSet: LastSetSnapshot? = nil
    /// Recommended next target; non-nil only for the current pending set.
    var suggestion: ProgressionSuggestion? = nil
    /// Reps in reserve recorded for this set, if any.
    var rir: Int? = nil
    /// Records an RIR value; nil hides the selector entirely.
    var onSelectRIR: ((Int) -> Void)? = nil

    @Environment(RestTimerModel.self) private var restTimer
    @Environment(AppSettings.self) private var settings

    @State private var repsText = ""
    @State private var weightText = ""
    @State private var showingPlateCalculator = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case weight, reps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldsRow
            if let suggestion, !set.isCompleted {
                suggestionButton(suggestion)
            }
            if set.isCompleted && !set.isWarmup, let onSelectRIR {
                rirSelector(onSelect: onSelectRIR)
            }
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.08) : Color.clear)
        .contextMenu {
            Button {
                set.isWarmup.toggle()
            } label: {
                Label(
                    set.isWarmup ? "Mark as Working Set" : "Mark as Warm-up",
                    systemImage: "flame"
                )
            }
            Button {
                showingPlateCalculator = true
            } label: {
                Label("Plate Calculator", systemImage: "circle.circle")
            }
        }
        .sheet(isPresented: $showingPlateCalculator) {
            PlateCalculatorView(initialWeight: set.weight > 0 ? set.weight : (lastSet?.weight ?? 0))
        }
        .onAppear {
            weightText = set.weight > 0 ? Format.editableWeight(set.weight) : ""
            repsText = set.reps > 0 ? "\(set.reps)" : ""
        }
        .onChange(of: weightText) { _, newValue in
            set.weight = Format.parseWeight(newValue)
        }
        .onChange(of: repsText) { _, newValue in
            set.reps = Int(newValue) ?? 0
        }
    }

    /// Position among working sets, so generated warm-ups don't shift the
    /// visible numbering to "4, 5, 6".
    private var workingSetNumber: Int {
        let peers = (set.workoutExercise?.orderedSets ?? []).filter { !$0.isWarmup }
        return (peers.firstIndex(where: { $0 === set }) ?? set.orderIndex) + 1
    }

    private var fieldsRow: some View {
        HStack(spacing: 10) {
            Text(set.isWarmup ? "W" : "\(workingSetNumber)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(set.isWarmup ? Color.orange : Color.secondary)
                .frame(width: 24)

            TextField(weightPlaceholder, text: $weightText)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 76)
            Text(settings.weightUnit.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(repsPlaceholder, text: $repsText)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)
            Text("reps")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                toggleCompleted()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    /// The tappable target chip: fills the fields with the recommendation.
    private func suggestionButton(_ suggestion: ProgressionSuggestion) -> some View {
        let tint = chipTint(for: suggestion.kind)
        return Button {
            weightText = suggestion.weight > 0 ? Format.editableWeight(suggestion.weight) : ""
            repsText = "\(suggestion.reps)"
        } label: {
            HStack(spacing: 6) {
                Image(systemName: chipIcon(for: suggestion.kind))
                    .font(.caption)
                if let label = chipLabel(for: suggestion.kind) {
                    Text(label)
                        .font(.caption2.bold())
                }
                if suggestion.weight > 0 {
                    Text("\(Format.plainWeight(suggestion.weight)) \(settings.weightUnit.displayName) × \(suggestion.reps)")
                        .font(.caption.bold())
                    if suggestion.kind == .progress || suggestion.kind == .hold {
                        Text("10RM \(Format.plainWeight((suggestion.estTenRM * 10).rounded() / 10))")
                            .font(.caption2)
                            .opacity(0.7)
                    }
                } else {
                    Text("× \(suggestion.reps)")
                        .font(.caption.bold())
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.borderless)
        .padding(.leading, 34)
    }

    private func chipIcon(for kind: ProgressionSuggestion.Kind) -> String {
        switch kind {
        case .progress: "scope"
        case .hold: "equal.circle"
        case .comeback: "arrow.uturn.backward"
        case .deload: "tortoise"
        }
    }

    private func chipTint(for kind: ProgressionSuggestion.Kind) -> Color {
        switch kind {
        case .progress, .hold: Color.accentColor
        case .comeback, .deload: Color.orange
        }
    }

    private func chipLabel(for kind: ProgressionSuggestion.Kind) -> String? {
        switch kind {
        case .progress, .hold: nil
        case .comeback: "Comeback"
        case .deload: "Deload"
        }
    }

    /// One-tap reps-in-reserve chips shown once a working set is completed.
    private func rirSelector(onSelect: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 6) {
            Text("RIR")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(0..<5, id: \.self) { value in
                let isSelected = rir.map { value == 4 ? $0 >= 4 : $0 == value } ?? false
                Button {
                    onSelect(value)
                } label: {
                    Text(value == 4 ? "4+" : "\(value)")
                        .font(.caption2.bold())
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .frame(minWidth: 26)
                        .padding(.vertical, 4)
                        .background(
                            isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.leading, 34)
    }

    private var weightPlaceholder: String {
        guard let lastSet, lastSet.weight > 0 else { return "0" }
        return Format.editableWeight(lastSet.weight)
    }

    private var repsPlaceholder: String {
        guard let lastSet, lastSet.reps > 0 else { return "0" }
        return "\(lastSet.reps)"
    }

    private func toggleCompleted() {
        if set.isCompleted {
            set.isCompleted = false
            set.completedAt = nil
        } else {
            adoptFallbackValuesIfEmpty()
            set.isCompleted = true
            set.completedAt = Date.now
            focusedField = nil
            if settings.autoStartRestTimer && !set.isWarmup {
                restTimer.start(duration: settings.restDuration(for: set.workoutExercise?.exerciseUUID))
            }
        }
    }

    /// Completing an untouched row logs the shown target/last-time numbers
    /// instead of a meaningless 0 × 0 that would drop out of all stats.
    private func adoptFallbackValuesIfEmpty() {
        if set.weight <= 0 {
            if let suggestion, suggestion.weight > 0 {
                set.weight = suggestion.weight
                weightText = Format.editableWeight(suggestion.weight)
            } else if let lastSet, lastSet.weight > 0 {
                set.weight = lastSet.weight
                weightText = Format.editableWeight(lastSet.weight)
            }
        }
        if set.reps <= 0 {
            if let suggestion, suggestion.reps > 0 {
                set.reps = suggestion.reps
                repsText = "\(suggestion.reps)"
            } else if let lastSet, lastSet.reps > 0 {
                set.reps = lastSet.reps
                repsText = "\(lastSet.reps)"
            }
        }
    }
}
