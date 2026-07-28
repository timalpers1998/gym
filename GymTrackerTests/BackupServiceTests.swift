import XCTest
import SwiftData
@testable import GymTracker

@MainActor
final class BackupServiceTests: XCTestCase {
    private func makeContext() -> ModelContext {
        ModelContainerFactory.make(inMemory: true).mainContext
    }

    /// Builds a store with one of everything the backup covers.
    private func populate(_ context: ModelContext) {
        let exercise = Exercise(name: "Test Bench", muscleGroup: .chest, isCustom: true)
        context.insert(exercise)

        let template = WorkoutTemplate(name: "Push Day")
        context.insert(template)
        let templateExercise = TemplateExercise(orderIndex: 0, exercise: exercise)
        templateExercise.template = template
        context.insert(templateExercise)
        let planned = TemplateSet(orderIndex: 0, targetReps: 8, targetWeight: 80)
        planned.templateExercise = templateExercise
        context.insert(planned)

        let workout = Workout(title: "Push Day", startDate: Date(timeIntervalSince1970: 1_700_000_000))
        workout.endDate = workout.startDate.addingTimeInterval(3600)
        workout.durationSeconds = 3600
        workout.sourceTemplate = template
        context.insert(workout)
        let workoutExercise = WorkoutExercise(orderIndex: 0, exercise: exercise)
        workoutExercise.workout = workout
        context.insert(workoutExercise)
        let set = SetEntry(orderIndex: 0, reps: 8, weight: 80, type: .failure, durationSeconds: 0)
        set.isCompleted = true
        set.workoutExercise = workoutExercise
        context.insert(set)

        context.insert(BodyWeightEntry(date: workout.startDate, weightKg: 82.5))
        context.insert(SetEffort(
            workoutStartDate: workout.startDate,
            exerciseUUID: exercise.uuid,
            setOrderIndex: 0,
            rir: 1
        ))
        context.insert(BodyMeasurement(date: workout.startDate, metric: .waist, valueCm: 84))
        try? context.save()
    }

    func testRoundTripIntoFreshStore() throws {
        let source = makeContext()
        populate(source)
        let settings = AppSettings()

        let url = try BackupService.export(context: source, settings: settings)
        defer { try? FileManager.default.removeItem(at: url) }

        let destination = makeContext()
        let summary = try BackupService.importBackup(
            from: url, context: destination, settings: settings
        )

        XCTAssertEqual(summary.workoutsAdded, 1)
        XCTAssertEqual(summary.templatesAdded, 1)
        XCTAssertEqual(summary.exercisesAdded, 1)
        XCTAssertEqual(summary.bodyWeightAdded, 1)
        XCTAssertEqual(summary.effortsAdded, 1)
        XCTAssertEqual(summary.measurementsAdded, 1)
        XCTAssertTrue(summary.settingsApplied)

        let workouts = try destination.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
        let set = workouts[0].orderedExercises[0].orderedSets[0]
        XCTAssertEqual(set.type, .failure)
        XCTAssertTrue(set.isCompleted)
        XCTAssertEqual(workouts[0].sourceTemplate?.name, "Push Day")

        // Effort rows must stay ==-linked to their workout's start date.
        let efforts = try destination.fetch(FetchDescriptor<SetEffort>())
        XCTAssertEqual(efforts.first?.workoutStartDate, workouts[0].startDate)
    }

    func testReimportIsNoOp() throws {
        let context = makeContext()
        populate(context)
        let settings = AppSettings()

        let url = try BackupService.export(context: context, settings: settings)
        defer { try? FileManager.default.removeItem(at: url) }

        let summary = try BackupService.importBackup(
            from: url, context: context, settings: settings
        )
        XCTAssertEqual(summary.workoutsAdded, 0)
        XCTAssertEqual(summary.templatesAdded, 0)
        XCTAssertEqual(summary.exercisesAdded, 0)
        XCTAssertEqual(summary.bodyWeightAdded, 0)
        XCTAssertEqual(summary.effortsAdded, 0)
        XCTAssertEqual(summary.measurementsAdded, 0)
        XCTAssertGreaterThan(summary.skipped, 0)
    }

    func testImportsFormatOneBackup() throws {
        let json = """
        {
          "formatVersion": 1,
          "exportedAt": "2026-01-01T10:00:00Z",
          "exercises": [{
            "uuid": "11111111-1111-1111-1111-111111111111",
            "name": "Legacy Bench",
            "muscleGroupRaw": "chest",
            "equipmentRaw": "barbell",
            "isCustom": true,
            "isArchived": false,
            "notes": "",
            "createdAt": "2026-01-01T10:00:00Z"
          }],
          "templates": [],
          "workouts": [{
            "title": "Legacy Push",
            "notes": "",
            "startDate": "2026-01-02T10:00:00.000Z",
            "endDate": "2026-01-02T11:00:00.000Z",
            "durationSeconds": 3600,
            "exercises": [{
              "orderIndex": 0,
              "exerciseName": "Legacy Bench",
              "exerciseUUID": "11111111-1111-1111-1111-111111111111",
              "notes": "",
              "sets": [{
                "orderIndex": 0,
                "reps": 8,
                "weight": 80,
                "isCompleted": true,
                "isWarmup": false
              }]
            }]
          }],
          "bodyWeight": [],
          "efforts": []
        }
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-backup-test.json")
        try json.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let context = makeContext()
        let summary = try BackupService.importBackup(
            from: url, context: context, settings: AppSettings()
        )
        XCTAssertEqual(summary.workoutsAdded, 1)
        XCTAssertEqual(summary.exercisesAdded, 1)

        // Fields the old format doesn't know get safe defaults.
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let set = workouts[0].orderedExercises[0].orderedSets[0]
        XCTAssertEqual(set.type, .working)
        XCTAssertEqual(set.durationSeconds, 0)
        XCTAssertNil(workouts[0].orderedExercises[0].supersetGroup)
    }

    func testRejectsFutureFormatVersion() throws {
        let json = """
        {"formatVersion": 99, "exportedAt": "2026-01-01T10:00:00Z",
         "exercises": [], "templates": [], "workouts": [],
         "bodyWeight": [], "efforts": []}
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("future-backup-test.json")
        try json.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try BackupService.importBackup(
            from: url, context: makeContext(), settings: AppSettings()
        ))
    }

    func testActiveWorkoutIsClosedOnImport() throws {
        let source = makeContext()
        let workout = Workout(title: "Interrupted", startDate: Date(timeIntervalSince1970: 1_700_000_000))
        context(source, addCompletedSetTo: workout)
        try? source.save()
        let settings = AppSettings()

        let url = try BackupService.export(context: source, settings: settings)
        defer { try? FileManager.default.removeItem(at: url) }

        let destination = makeContext()
        _ = try BackupService.importBackup(from: url, context: destination, settings: settings)
        let imported = try destination.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(imported.count, 1)
        XCTAssertNotNil(imported[0].endDate, "An imported backup must never plant an active session")
    }

    private func context(_ context: ModelContext, addCompletedSetTo workout: Workout) {
        context.insert(workout)
        let exercise = Exercise(name: "Squat", muscleGroup: .legs)
        context.insert(exercise)
        let workoutExercise = WorkoutExercise(orderIndex: 0, exercise: exercise)
        workoutExercise.workout = workout
        context.insert(workoutExercise)
        let set = SetEntry(orderIndex: 0, reps: 5, weight: 100)
        set.isCompleted = true
        set.completedAt = workout.startDate.addingTimeInterval(300)
        set.workoutExercise = workoutExercise
        context.insert(set)
    }
}
