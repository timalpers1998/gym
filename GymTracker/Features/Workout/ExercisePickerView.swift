import SwiftUI
import SwiftData

/// Searchable multi-select exercise picker, shared by the active workout and
/// the routine editor.
struct ExercisePickerView: View {
    let onAdd: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Exercise.name)
    private var allExercises: [Exercise]

    @State private var searchText = ""
    @State private var selected: Set<PersistentIdentifier> = []
    @State private var showingNewExercise = false

    private var visibleExercises: [Exercise] {
        allExercises.filter { exercise in
            !exercise.isArchived
                && (searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    private struct ExerciseGroup: Identifiable {
        let group: MuscleGroup
        let exercises: [Exercise]
        var id: MuscleGroup { group }
    }

    private var groupedExercises: [ExerciseGroup] {
        MuscleGroup.allCases.compactMap { group in
            let members = visibleExercises.filter { $0.muscleGroup == group }
            return members.isEmpty ? nil : ExerciseGroup(group: group, exercises: members)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedExercises) { entry in
                    Section(entry.group.displayName) {
                        ForEach(entry.exercises) { exercise in
                            row(for: exercise)
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add (\(selected.count))") {
                        confirm()
                    }
                    .disabled(selected.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showingNewExercise = true
                    } label: {
                        Label("New Custom Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewExercise) {
                ExerciseEditorView(exercise: nil) { created in
                    selected.insert(created.persistentModelID)
                }
            }
        }
    }

    private func row(for exercise: Exercise) -> some View {
        Button {
            toggle(exercise)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .foregroundStyle(.primary)
                    Text(exercise.equipment.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selected.contains(exercise.persistentModelID) {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func toggle(_ exercise: Exercise) {
        if selected.contains(exercise.persistentModelID) {
            selected.remove(exercise.persistentModelID)
        } else {
            selected.insert(exercise.persistentModelID)
        }
    }

    private func confirm() {
        let chosen = allExercises.filter { selected.contains($0.persistentModelID) }
        onAdd(chosen)
        dismiss()
    }
}
