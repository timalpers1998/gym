import AppIntents
import Foundation
import SwiftData

/// Errors surfaced to Siri/Shortcuts as spoken dialog.
struct GymIntentError: Error, CustomLocalizedStringResourceConvertible {
    let message: String

    var localizedStringResource: LocalizedStringResource { "\(message)" }
}

private struct RoutineOptionsProvider: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [String] {
        let context = ModelContainerFactory.shared.mainContext
        let templates = (try? context.fetch(
            FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.name)])
        )) ?? []
        return templates.map(\.name).filter { !$0.isEmpty }
    }
}

/// "Start a workout in GymTracker" — optionally from a routine. Opens the
/// app on the Workout tab with the session running.
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription(
        "Starts a workout, optionally from one of your routines."
    )
    static let openAppWhenRun = true

    @Parameter(title: "Routine", optionsProvider: RoutineOptionsProvider())
    var routine: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContainerFactory.shared.mainContext
        let active = (try? context.fetch(
            FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endDate == nil })
        )) ?? []
        let dialog: IntentDialog
        if active.isEmpty {
            if let routine, !routine.isEmpty {
                let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
                guard let template = templates.first(where: {
                    $0.name.compare(routine, options: [.caseInsensitive]) == .orderedSame
                }) else {
                    throw GymIntentError(message: "There is no routine named \(routine).")
                }
                WorkoutFactory.startWorkout(from: template, context: context)
                dialog = "Started \(template.name)."
            } else {
                WorkoutFactory.startEmptyWorkout(context: context)
                dialog = "Workout started."
            }
        } else {
            dialog = "You already have a workout in progress."
        }
        NotificationCenter.default.post(name: .openWorkoutTab, object: nil)
        return .result(dialog: dialog)
    }
}

/// "Log my weight in GymTracker" — runs in the background, no UI needed.
struct LogBodyWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Body Weight"
    static let description = IntentDescription(
        "Saves a body weight entry, in the unit the app is set to."
    )

    @Parameter(title: "Weight")
    var weight: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard weight > 0, weight < 1000 else {
            throw GymIntentError(message: "That doesn't look like a body weight.")
        }
        let settings = AppSettings()
        let kilograms = weight * settings.weightUnit.kilogramsPerUnit
        let context = ModelContainerFactory.shared.mainContext
        context.insert(BodyWeightEntry(date: .now, weightKg: kilograms))
        try context.save()
        await HealthService.saveBodyWeight(kilograms: kilograms, date: .now)
        return .result(
            dialog: "Logged \(Format.plainWeight(weight)) \(settings.weightUnit.displayName)."
        )
    }
}

struct GymTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout in \(.applicationName)",
                "Start my workout in \(.applicationName)",
                "Start lifting in \(.applicationName)",
            ],
            shortTitle: "Start Workout",
            systemImageName: "dumbbell.fill"
        )
        AppShortcut(
            intent: LogBodyWeightIntent(),
            phrases: [
                "Log my weight in \(.applicationName)",
                "Log my body weight in \(.applicationName)",
            ],
            shortTitle: "Log Body Weight",
            systemImageName: "scalemass"
        )
    }
}

extension Notification.Name {
    /// Posted by StartWorkoutIntent so the root tab view can jump to the
    /// Workout tab when the intent fires while the app is already open.
    static let openWorkoutTab = Notification.Name("GymTracker.openWorkoutTab")
}
