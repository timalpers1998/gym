import SwiftUI
import SwiftData

/// Creates a custom exercise (exercise == nil) or edits an existing one.
struct ExerciseEditorView: View {
    let exercise: Exercise?
    var onSave: ((Exercise) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .other
    @State private var equipment: Equipment = .other
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
                    notes = exercise.notes
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
            exercise.notes = notes
            try? context.save()
        } else {
            let created = Exercise(
                name: trimmed,
                muscleGroup: muscleGroup,
                equipment: equipment,
                isCustom: true,
                notes: notes
            )
            context.insert(created)
            try? context.save()
            onSave?(created)
        }
        dismiss()
    }
}
