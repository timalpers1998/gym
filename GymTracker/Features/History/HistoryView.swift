import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate, order: .reverse)
    private var workouts: [Workout]

    private var monthSections: [(month: Date, workouts: [Workout])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.dateInterval(of: .month, for: workout.startDate)?.start ?? workout.startDate
        }
        return grouped.keys.sorted(by: >).map { key in
            (month: key, workouts: grouped[key] ?? [])
        }
    }

    var body: some View {
        List {
            ForEach(monthSections, id: \.month) { section in
                Section(section.month.formatted(.dateTime.month(.wide).year())) {
                    ForEach(section.workouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            WorkoutRowView(workout: workout)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .overlay {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Finished workouts show up here.")
                )
            }
        }
    }
}
