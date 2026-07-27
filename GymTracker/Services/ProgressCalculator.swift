import Foundation
import SwiftData

struct ExerciseDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let topSetWeight: Double
    let totalVolume: Double
    let bestE1RM: Double
}

struct PersonalRecords {
    let heaviestWeight: Double
    let heaviestWeightReps: Int
    let heaviestWeightDate: Date
    let bestE1RM: Double
    let bestE1RMDate: Date
    let bestSessionVolume: Double
    let bestSessionVolumeDate: Date
}

struct RecentPR: Identifiable {
    let id = UUID()
    let exerciseName: String
    let exerciseUUID: UUID?
    let weight: Double
    let reps: Int
    let date: Date
}

struct WeeklyCount: Identifiable {
    let weekStart: Date
    let count: Int
    var id: Date { weekStart }
}

enum ProgressCalculator {
    static func epleyOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    /// One data point per finished workout that contains completed working sets
    /// of the exercise.
    static func dataPoints(for entries: [WorkoutExercise]) -> [ExerciseDataPoint] {
        var byWorkout: [PersistentIdentifier: (date: Date, sets: [SetEntry])] = [:]
        for entry in entries {
            guard let workout = entry.workout, workout.endDate != nil else { continue }
            let sets = entry.completedSets.filter { !$0.isWarmup && $0.reps > 0 }
            guard !sets.isEmpty else { continue }
            byWorkout[workout.persistentModelID, default: (workout.startDate, [])].sets.append(contentsOf: sets)
        }

        return byWorkout.values
            .map { date, sets in
                ExerciseDataPoint(
                    date: date,
                    topSetWeight: sets.map(\.weight).max() ?? 0,
                    totalVolume: sets.reduce(0) { $0 + $1.volume },
                    bestE1RM: sets.map { epleyOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                )
            }
            .sorted { $0.date < $1.date }
    }

    static func personalRecords(for entries: [WorkoutExercise]) -> PersonalRecords? {
        var heaviest: (weight: Double, reps: Int, date: Date)?
        var bestE1RM: (value: Double, date: Date)?
        var bestSession: (volume: Double, date: Date)?

        for point in dataPoints(for: entries) {
            if bestSession == nil || point.totalVolume > bestSession!.volume {
                bestSession = (point.totalVolume, point.date)
            }
        }

        for entry in entries {
            guard let workout = entry.workout, workout.endDate != nil else { continue }
            for set in entry.completedSets where !set.isWarmup && set.reps > 0 && set.weight > 0 {
                let date = set.completedAt ?? workout.startDate
                if heaviest == nil || set.weight > heaviest!.weight {
                    heaviest = (set.weight, set.reps, date)
                }
                let e1rm = epleyOneRepMax(weight: set.weight, reps: set.reps)
                if bestE1RM == nil || e1rm > bestE1RM!.value {
                    bestE1RM = (e1rm, date)
                }
            }
        }

        guard let heaviest, let bestE1RM, let bestSession else { return nil }
        return PersonalRecords(
            heaviestWeight: heaviest.weight,
            heaviestWeightReps: heaviest.reps,
            heaviestWeightDate: heaviest.date,
            bestE1RM: bestE1RM.value,
            bestE1RMDate: bestE1RM.date,
            bestSessionVolume: bestSession.volume,
            bestSessionVolumeDate: bestSession.date
        )
    }

    /// PR events across all exercises: every completed set whose estimated 1RM
    /// beat all earlier sets of the same exercise. Newest first.
    static func recentPRs(entries: [WorkoutExercise], limit: Int = 5) -> [RecentPR] {
        struct SetEvent {
            let uuid: UUID?
            let name: String
            let weight: Double
            let reps: Int
            let date: Date
            let e1rm: Double
        }

        var events: [SetEvent] = []
        for entry in entries {
            guard let workout = entry.workout, workout.endDate != nil else { continue }
            for set in entry.completedSets where !set.isWarmup && set.reps > 0 && set.weight > 0 {
                events.append(SetEvent(
                    uuid: entry.exerciseUUID,
                    name: entry.exerciseName,
                    weight: set.weight,
                    reps: set.reps,
                    date: set.completedAt ?? workout.startDate,
                    e1rm: epleyOneRepMax(weight: set.weight, reps: set.reps)
                ))
            }
        }
        events.sort { $0.date < $1.date }

        var bestByExercise: [String: Double] = [:]
        var prs: [RecentPR] = []
        for event in events {
            let key = event.uuid?.uuidString ?? event.name
            if event.e1rm > (bestByExercise[key] ?? 0) {
                bestByExercise[key] = event.e1rm
                prs.append(RecentPR(
                    exerciseName: event.name,
                    exerciseUUID: event.uuid,
                    weight: event.weight,
                    reps: event.reps,
                    date: event.date
                ))
            }
        }
        return Array(prs.suffix(limit).reversed())
    }

    static func weeklyCounts(
        workouts: [Workout],
        weeks: Int,
        calendar: Calendar = .current,
        now: Date = Date.now
    ) -> [WeeklyCount] {
        guard weeks > 0,
              let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
        else { return [] }

        var counts: [Date: Int] = [:]
        for workout in workouts where workout.endDate != nil {
            if let start = calendar.dateInterval(of: .weekOfYear, for: workout.startDate)?.start {
                counts[start, default: 0] += 1
            }
        }

        var result: [WeeklyCount] = []
        for offset in stride(from: -(weeks - 1), through: 0, by: 1) {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeekStart) {
                result.append(WeeklyCount(weekStart: weekStart, count: counts[weekStart] ?? 0))
            }
        }
        return result
    }

    /// Consecutive weeks with at least one finished workout, counting backward
    /// from the current week (a quiet current week doesn't break the streak).
    static func weeklyStreak(
        workouts: [Workout],
        calendar: Calendar = .current,
        now: Date = Date.now
    ) -> Int {
        let weekStarts = Set(workouts.compactMap { workout -> Date? in
            guard workout.endDate != nil else { return nil }
            return calendar.dateInterval(of: .weekOfYear, for: workout.startDate)?.start
        })

        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }

        var cursor = currentWeekStart
        if !weekStarts.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }

        var streak = 0
        while weekStarts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Hard sets (completed, non-warm-up, reps > 0) per muscle group: current
    /// week plus the average of the four preceding weeks.
    static func muscleWeekVolumes(
        entries: [WorkoutExercise],
        calendar: Calendar = .current,
        now: Date = Date.now
    ) -> [MuscleWeekVolume] {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now),
              let historyStart = calendar.date(byAdding: .weekOfYear, value: -4, to: currentWeek.start)
        else { return [] }

        var thisWeek: [MuscleGroup: Int] = [:]
        var previousWeeks: [MuscleGroup: Int] = [:]

        for entry in entries {
            guard let workout = entry.workout, workout.endDate != nil else { continue }
            let date = workout.startDate
            guard date >= historyStart else { continue }
            let group = entry.exercise?.muscleGroup ?? .other
            let hardSets = entry.orderedSets
                .filter { $0.isCompleted && !$0.isWarmup && $0.reps > 0 }
                .count
            guard hardSets > 0 else { continue }
            if date >= currentWeek.start {
                thisWeek[group, default: 0] += hardSets
            } else {
                previousWeeks[group, default: 0] += hardSets
            }
        }

        let groups = Set(thisWeek.keys).union(previousWeeks.keys)
        return groups
            .map { group in
                MuscleWeekVolume(
                    group: group,
                    thisWeek: thisWeek[group] ?? 0,
                    weeklyAverage: Double(previousWeeks[group] ?? 0) / 4
                )
            }
            .sorted {
                if $0.thisWeek != $1.thisWeek { return $0.thisWeek > $1.thisWeek }
                return $0.group.displayName < $1.group.displayName
            }
    }
}

struct MuscleWeekVolume: Identifiable {
    let group: MuscleGroup
    let thisWeek: Int
    /// Mean hard sets per week over the four preceding weeks.
    let weeklyAverage: Double
    var id: MuscleGroup { group }
}
