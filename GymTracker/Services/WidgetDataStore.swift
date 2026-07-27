import Foundation
import SwiftData
import WidgetKit

/// Publishes a small summary of workout stats to the shared App Group so the
/// Home Screen widget can render without access to the SwiftData store.
@MainActor
enum WidgetDataStore {
    static func refresh(context: ModelContext) {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endDate != nil }
        )
        guard let workouts = try? context.fetch(descriptor) else { return }

        let calendar = Calendar.current
        let now = Date.now
        let weekCount = ProgressCalculator
            .weeklyCounts(workouts: workouts, weeks: 1, calendar: calendar, now: now)
            .last?.count ?? 0
        let streak = ProgressCalculator.weeklyStreak(workouts: workouts, calendar: calendar, now: now)
        let latest = workouts.max { $0.startDate < $1.startDate }

        var weekDays = [Bool](repeating: false, count: 7)
        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) {
            for workout in workouts
            where workout.startDate >= weekInterval.start && workout.startDate < weekInterval.end {
                let dayIndex = calendar.dateComponents(
                    [.day],
                    from: weekInterval.start,
                    to: calendar.startOfDay(for: workout.startDate)
                ).day ?? 0
                if dayIndex >= 0 && dayIndex < 7 {
                    weekDays[dayIndex] = true
                }
            }
        }

        let summary = WidgetSummary(
            weekCount: weekCount,
            weekStreak: streak,
            lastWorkoutTitle: latest?.title,
            lastWorkoutDate: latest?.startDate,
            weekDays: weekDays,
            generatedAt: now
        )

        guard let defaults = UserDefaults(suiteName: WidgetShared.appGroupID),
              let data = try? JSONEncoder().encode(summary)
        else { return }
        defaults.set(data, forKey: WidgetShared.summaryKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
