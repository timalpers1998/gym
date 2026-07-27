import SwiftUI
import SwiftData

struct WorkoutTabView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Workout> { $0.endDate == nil }, sort: \Workout.startDate)
    private var activeWorkouts: [Workout]

    @Query(sort: \WorkoutTemplate.name)
    private var templates: [WorkoutTemplate]

    @State private var showingSettings = false

    var body: some View {
        Group {
            if let active = activeWorkouts.first {
                ActiveWorkoutView(workout: active)
            } else {
                idleContent
            }
        }
        .navigationTitle(activeWorkouts.isEmpty ? "Workout" : "Active Workout")
        .toolbar {
            if activeWorkouts.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var idleContent: some View {
        List {
            Section {
                Button {
                    WorkoutFactory.startEmptyWorkout(context: context)
                } label: {
                    Label("Start Empty Workout", systemImage: "play.fill")
                        .font(.headline)
                }
            }

            Section("Routines") {
                if templates.isEmpty {
                    Text("Create a routine to start workouts with one tap.")
                        .foregroundStyle(.secondary)
                }
                ForEach(templates) { template in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                            Text(routineSummary(for: template))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Start") {
                            WorkoutFactory.startWorkout(from: template, context: context)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                NavigationLink("Manage Routines") {
                    TemplateListView()
                }
            }
        }
    }

    private func routineSummary(for template: WorkoutTemplate) -> String {
        let exercises = template.orderedExercises
        if exercises.isEmpty { return "No exercises yet" }
        let names = exercises.prefix(3).map(\.exerciseName).joined(separator: ", ")
        let extra = exercises.count > 3 ? " +\(exercises.count - 3)" : ""
        return names + extra
    }
}
