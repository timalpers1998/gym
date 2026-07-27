import SwiftUI

struct WorkoutRowView: View {
    let workout: Workout

    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.title)
                    .font(.headline)
                Spacer()
                Text(workout.startDate.formatted(.dateTime.weekday().day().month()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(Format.duration(seconds: workout.durationSeconds), systemImage: "clock")
                Label("\(workout.orderedExercises.count) exercises", systemImage: "dumbbell")
                if workout.totalVolume > 0 {
                    Label(Format.weight(workout.totalVolume, unit: settings.weightUnit), systemImage: "scalemass")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
