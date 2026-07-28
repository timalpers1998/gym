import XCTest
import SwiftData
@testable import GymTracker

@MainActor
final class ProgressCalculatorTests: XCTestCase {
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = ModelContainerFactory.make(inMemory: true).mainContext
    }

    /// One finished workout containing one exercise entry with the given sets.
    private func makeEntry(
        exercise: Exercise,
        daysAgo: Int,
        sets: [(reps: Int, weight: Double, duration: Int)]
    ) -> WorkoutExercise {
        let workout = Workout(
            title: "W",
            startDate: Date.now.addingTimeInterval(TimeInterval(-daysAgo * 86_400))
        )
        workout.endDate = workout.startDate.addingTimeInterval(3600)
        context.insert(workout)
        let entry = WorkoutExercise(orderIndex: 0, exercise: exercise)
        entry.workout = workout
        context.insert(entry)
        for (index, spec) in sets.enumerated() {
            let set = SetEntry(
                orderIndex: index,
                reps: spec.reps,
                weight: spec.weight,
                durationSeconds: spec.duration
            )
            set.isCompleted = true
            set.workoutExercise = entry
            context.insert(set)
        }
        try? context.save()
        return entry
    }

    func testDataPointsForRepsExercise() {
        let exercise = Exercise(name: "Bench", muscleGroup: .chest)
        context.insert(exercise)
        let first = makeEntry(exercise: exercise, daysAgo: 7, sets: [(8, 80, 0), (8, 82.5, 0)])
        let second = makeEntry(exercise: exercise, daysAgo: 1, sets: [(8, 85, 0)])

        let points = ProgressCalculator.dataPoints(for: [first, second])
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].topSetWeight, 82.5)
        XCTAssertEqual(points[1].topSetWeight, 85)
        XCTAssertEqual(points[0].totalVolume, 8 * 80 + 8 * 82.5)
    }

    func testDataPointsIncludeDurationOnlySets() {
        let plank = Exercise(name: "Plank", muscleGroup: .core, measurement: .duration)
        context.insert(plank)
        let entry = makeEntry(exercise: plank, daysAgo: 2, sets: [(0, 0, 60), (0, 0, 90)])

        let points = ProgressCalculator.dataPoints(for: [entry])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].topDuration, 90)
        XCTAssertEqual(points[0].totalDuration, 150)
    }

    func testRecentPRsIgnoreDurationExercises() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest)
        // A weighted plank (weight > 0 with phantom-free reps) must not
        // produce a PR row even if reps were somehow recorded.
        let plank = Exercise(name: "Plank", muscleGroup: .core, measurement: .duration)
        context.insert(bench)
        context.insert(plank)
        let benchEntry = makeEntry(exercise: bench, daysAgo: 3, sets: [(8, 80, 0)])
        let plankEntry = makeEntry(exercise: plank, daysAgo: 2, sets: [(10, 25, 60)])

        let prs = ProgressCalculator.recentPRs(entries: [benchEntry, plankEntry])
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs[0].exerciseName, "Bench")
    }

    func testPersonalRecordsNilWithoutWeightedSets() {
        let plank = Exercise(name: "Plank", muscleGroup: .core, measurement: .duration)
        context.insert(plank)
        let entry = makeEntry(exercise: plank, daysAgo: 1, sets: [(0, 0, 60)])
        XCTAssertNil(ProgressCalculator.personalRecords(for: [entry]))
    }

    func testWeeklyStreakCountsConsecutiveWeeks() {
        let exercise = Exercise(name: "Bench", muscleGroup: .chest)
        context.insert(exercise)
        _ = makeEntry(exercise: exercise, daysAgo: 2, sets: [(8, 80, 0)])
        _ = makeEntry(exercise: exercise, daysAgo: 9, sets: [(8, 80, 0)])

        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        XCTAssertGreaterThanOrEqual(ProgressCalculator.weeklyStreak(workouts: workouts), 1)
    }
}
