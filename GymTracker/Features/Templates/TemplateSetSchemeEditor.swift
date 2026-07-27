import SwiftUI
import SwiftData

struct TemplateSetSchemeEditor: View {
    let templateExercise: TemplateExercise

    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section("Target Sets") {
                ForEach(templateExercise.orderedSets) { set in
                    TemplateSetRow(
                        set: set,
                        measurement: templateExercise.exercise?.measurement ?? .reps
                    )
                }
                .onDelete { offsets in
                    deleteSets(at: offsets)
                }

                Button {
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(templateExercise.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addSet() {
        let ordered = templateExercise.orderedSets
        let nextIndex = (ordered.map(\.orderIndex).max() ?? -1) + 1
        let last = ordered.last
        let set = TemplateSet(
            orderIndex: nextIndex,
            targetReps: last?.targetReps ?? 10,
            targetWeight: last?.targetWeight ?? 0,
            targetDurationSeconds: last?.targetDurationSeconds ?? 0
        )
        set.templateExercise = templateExercise
        context.insert(set)
    }

    private func deleteSets(at offsets: IndexSet) {
        let ordered = templateExercise.orderedSets
        for index in offsets {
            context.delete(ordered[index])
        }
        let remaining = ordered.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        for (index, set) in remaining.enumerated() {
            set.orderIndex = index
        }
    }
}

private struct TemplateSetRow: View {
    let set: TemplateSet
    let measurement: ExerciseMeasurement

    @Environment(AppSettings.self) private var settings

    @State private var repsText = ""
    @State private var weightText = ""
    @State private var durationText = ""

    var body: some View {
        HStack(spacing: 10) {
            Text("\(set.orderIndex + 1)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.secondary)
                .frame(width: 24)

            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 76)
            Text(settings.weightUnit.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            if measurement == .duration {
                TextField("0:30", text: $durationText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                Text("min:sec")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                TextField("10", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .onAppear {
            weightText = set.targetWeight > 0 ? Format.editableWeight(set.targetWeight) : ""
            repsText = "\(set.targetReps)"
            durationText = set.targetDurationSeconds > 0
                ? Format.editableDuration(set.targetDurationSeconds)
                : ""
        }
        .onChange(of: weightText) { _, newValue in
            set.targetWeight = Format.parseWeight(newValue)
        }
        .onChange(of: repsText) { _, newValue in
            set.targetReps = Int(newValue) ?? 0
        }
        .onChange(of: durationText) { _, newValue in
            set.targetDurationSeconds = Format.parseDuration(newValue)
        }
    }
}
