import Foundation

/// Shared between the app (writer) and the widget (reader).
enum WidgetShared {
    static let appGroupID = "group.com.example.GymTracker"
    static let summaryKey = "widgetSummary"
}

struct WidgetSummary: Codable {
    var weekCount: Int
    var weekStreak: Int
    var lastWorkoutTitle: String?
    var lastWorkoutDate: Date?
    /// One flag per day of the current week, in calendar order starting at
    /// the locale's first weekday.
    var weekDays: [Bool]
    var generatedAt: Date
}
