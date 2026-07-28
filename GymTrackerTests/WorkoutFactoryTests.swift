import XCTest
import SwiftData
@testable import GymTracker

@MainActor
final class WorkoutFactoryTests: XCTestCase {
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = ModelContainerFactory.make(inMemory: true).mainContext
    }

    private func makeWorkout(exerciseCount: Int) -> Workout {
        let workout = Workout(title: "Test")
        context.insert(workout)
        for index in 0..<exerciseCount {
            let exercise = Exercise(name: "Exercise \(index)", muscleGroup: .chest)
            context.insert(exercise)
            let workoutExercise = WorkoutExercise(orderIndex: index, exercise: exercise)
            workoutExercise.workout = workout
            context.insert(workoutExercise)
        }
        try? context.save()
        return workout
    }

    func testSupersetWithNextLinksPair() {
        let workout = makeWorkout(exerciseCount: 3)
        let ordered = workout.orderedExercises
        WorkoutFactory.supersetWithNext(ordered[0], context: context)
        XCTAssertNotNil(ordered[0].supersetGroup)
        XCTAssertEqual(ordered[0].supersetGroup, ordered[1].supersetGroup)
        XCTAssertNil(ordered[2].supersetGroup)
    }

    func testChainingBuildsTriSet() {
        let workout = makeWorkout(exerciseCount: 3)
        let ordered = workout.orderedExercises
        WorkoutFactory.supersetWithNext(ordered[0], context: context)
        WorkoutFactory.supersetWithNext(ordered[1], context: context)
        let groups = Set(ordered.compactMap(\.supersetGroup))
        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(ordered.allSatisfy { $0.supersetGroup != nil })
    }

    /// Joining two existing pairs must merge every member into one group —
    /// no stranded singletons.
    func testJoiningTwoPairsMergesAllMembers() {
        let workout = makeWorkout(exerciseCount: 4)
        let ordered = workout.orderedExercises
        WorkoutFactory.supersetWithNext(ordered[0], context: context)
        WorkoutFactory.supersetWithNext(ordered[2], context: context)
        XCTAssertNotEqual(ordered[0].supersetGroup, ordered[2].supersetGroup)
        WorkoutFactory.supersetWithNext(ordered[1], context: context)
        let groups = Set(ordered.compactMap(\.supersetGroup))
        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(ordered.allSatisfy { $0.supersetGroup != nil })
    }

    func testRemoveFromSupersetDissolvesSingletonGroup() {
        let workout = makeWorkout(exerciseCount: 2)
        let ordered = workout.orderedExercises
        WorkoutFactory.supersetWithNext(ordered[0], context: context)
        WorkoutFactory.removeFromSuperset(ordered[0], context: context)
        XCTAssertNil(ordered[0].supersetGroup)
        XCTAssertNil(ordered[1].supersetGroup)
    }

    func testStartWorkoutFromTemplateCarriesSupersetsAndDurations() {
        let repsExercise = Exercise(name: "Bench", muscleGroup: .chest)
        let durationExercise = Exercise(name: "Plank", muscleGroup: .core, measurement: .duration)
        context.insert(repsExercise)
        context.insert(durationExercise)

        let template = WorkoutTemplate(name: "Mixed")
        context.insert(template)
        let first = TemplateExercise(orderIndex: 0, exercise: repsExercise)
        first.template = template
        context.insert(first)
        let second = TemplateExercise(orderIndex: 1, exercise: durationExercise)
        second.template = template
        context.insert(second)
        let repsSet = TemplateSet(orderIndex: 0, targetReps: 8, targetWeight: 80)
        repsSet.templateExercise = first
        context.insert(repsSet)
        let durationSet = TemplateSet(orderIndex: 0, targetDurationSeconds: 60)
        durationSet.templateExercise = second
        context.insert(durationSet)
        WorkoutFactory.supersetWithNext(first, context: context)

        let workout = WorkoutFactory.startWorkout(from: template, context: context)
        let exercises = workout.orderedExercises
        XCTAssertEqual(exercises.count, 2)
        XCTAssertNotNil(exercises[0].supersetGroup)
        XCTAssertEqual(exercises[0].supersetGroup, exercises[1].supersetGroup)

        let benchSet = exercises[0].orderedSets[0]
        XCTAssertEqual(benchSet.reps, 8)
        XCTAssertEqual(benchSet.weight, 80)

        // Duration exercises must not inherit template rep defaults —
        // phantom reps would fake volume and PRs.
        let plankSet = exercises[1].orderedSets[0]
        XCTAssertEqual(plankSet.reps, 0)
        XCTAssertEqual(plankSet.durationSeconds, 60)
    }

    func testRemoveIncompleteSetsDissolvesEmptiedSuperset() {
        let workout = makeWorkout(exerciseCount: 2)
        let ordered = workout.orderedExercises
        WorkoutFactory.supersetWithNext(ordered[0], context: context)

        let completed = SetEntry(orderIndex: 0, reps: 8, weight: 60)
        completed.isCompleted = true
        completed.workoutExercise = ordered[0]
        context.insert(completed)
        let pending = SetEntry(orderIndex: 0, reps: 8, weight: 60)
        pending.workoutExercise = ordered[1]
        context.insert(pending)
        try? context.save()

        WorkoutFactory.removeIncompleteSets(in: workout, context: context)

        let remaining = workout.orderedExercises
        XCTAssertEqual(remaining.count, 1)
        XCTAssertNil(remaining[0].supersetGroup)
    }

    func testRepeatWorkoutCopiesTypesAndDurations() {
        let workout = makeWorkout(exerciseCount: 1)
        let exercise = workout.orderedExercises[0]
        let set = SetEntry(orderIndex: 0, reps: 6, weight: 100, type: .dropSet, durationSeconds: 45)
        set.isCompleted = true
        set.workoutExercise = exercise
        context.insert(set)
        try? context.save()

        let copy = WorkoutFactory.repeatWorkout(workout, context: context)
        let copiedSet = copy.orderedExercises[0].orderedSets[0]
        XCTAssertEqual(copiedSet.type, .dropSet)
        XCTAssertEqual(copiedSet.durationSeconds, 45)
        XCTAssertFalse(copiedSet.isCompleted)
    }
}
