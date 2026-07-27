import Foundation

enum CSVExporter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Writes every set of the given workouts to a CSV file in the temporary
    /// directory and returns its URL.
    static func export(workouts: [Workout]) throws -> URL {
        var lines = ["date,workout,exercise,set,warmup,type,superset,weight,reps,duration_seconds,completed"]

        for workout in workouts.sorted(by: { $0.startDate < $1.startDate }) {
            let date = dateFormatter.string(from: workout.startDate)
            for exercise in workout.orderedExercises {
                for set in exercise.orderedSets {
                    let fields = [
                        date,
                        workout.title,
                        exercise.exerciseName,
                        "\(set.orderIndex + 1)",
                        set.isWarmup ? "yes" : "no",
                        set.type.rawValue,
                        exercise.supersetGroup.map { "\($0)" } ?? "",
                        Format.editableWeight(set.weight),
                        "\(set.reps)",
                        "\(set.durationSeconds)",
                        set.isCompleted ? "yes" : "no",
                    ]
                    lines.append(fields.map(escape).joined(separator: ","))
                }
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymTracker-export.csv")
        try (lines.joined(separator: "\n") + "\n")
            .write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
