import SwiftUI
import SwiftData

/// Creates a custom exercise (exercise == nil) or edits an existing one.
struct ExerciseEditorView: View {
    let exercise: Exercise?
    /// Pre-fills the name when creating from a search with no matches.
    var initialName: String = ""
    var onSave: ((Exercise) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .other
    @State private var equipment: Equipment = .other
    @State private var measurement: ExerciseMeasurement = .reps
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)

                Picker("Muscle Group", selection: $muscleGroup) {
                    ForEach(MuscleGroup.allCases) { group in
                        Text(group.displayName).tag(group)
                    }
                }

                Picker("Equipment", selection: $equipment) {
                    ForEach(Equipment.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }

                Section {
                    Picker("Logged as", selection: $measurement) {
                        ForEach(ExerciseMeasurement.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                } footer: {
                    Text("Duration exercises (planks, carries, holds) log time under load instead of reps.")
                }

                Section("Notes") {
                    TextField("Cues, seat height, grip…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let exercise {
                    name = exercise.name
                    muscleGroup = exercise.muscleGroup
                    equipment = exercise.equipment
                    measurement = exercise.measurement
                    notes = exercise.notes
                } else if name.isEmpty {
                    name = initialName.trimmingCharacters(in: .whitespaces)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let exercise {
            exercise.name = trimmed
            exercise.muscleGroup = muscleGroup
            exercise.equipment = equipment
            exercise.measurement = measurement
            exercise.notes = notes
            try? context.save()
        } else {
            let created = Exercise(
                name: trimmed,
                muscleGroup: muscleGroup,
                equipment: equipment,
                isCustom: true,
                notes: notes,
                measurement: measurement
            )
            context.insert(created)
            try? context.save()
            onSave?(created)
        }
        dismiss()
    }
}
