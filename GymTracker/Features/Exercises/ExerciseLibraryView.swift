import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Query(sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var showingNewExercise = false
    @State private var showArchived = false

    private var visibleExercises: [Exercise] {
        exercises.filter { exercise in
            (showArchived || !exercise.isArchived)
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
        List {
            ForEach(groupedExercises) { entry in
                Section(entry.group.displayName) {
                    ForEach(entry.exercises) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                    Text(exercise.equipment.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if exercise.isArchived {
                                    Image(systemName: "archivebox")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Exercises")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Toggle("Show Archived", isOn: $showArchived)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewExercise) {
            ExerciseEditorView(exercise: nil)
        }
        .overlay {
            if visibleExercises.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Archived exercises are hidden. Use the filter to show them, or add a new exercise.")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}
