import Foundation
import SwiftData

@MainActor
enum WorkoutFactory {
    @discardableResult
    static func startEmptyWorkout(context: ModelContext) -> Workout {
        let workout = Workout(title: "Workout")
        context.insert(workout)
        try? context.save()
        return workout
    }

    @discardableResult
    static func startWorkout(from template: WorkoutTemplate, context: ModelContext) -> Workout {
        let workout = Workout(title: template.name, sourceTemplate: template)
        context.insert(workout)

        for templateExercise in template.orderedExercises {
            let workoutExercise: WorkoutExercise
            if let exercise = templateExercise.exercise {
                workoutExercise = WorkoutExercise(orderIndex: templateExercise.orderIndex, exercise: exercise)
            } else {
                workoutExercise = WorkoutExercise(
                    orderIndex: templateExercise.orderIndex,
                    exerciseName: templateExercise.exerciseName,
                    exerciseUUID: templateExercise.exerciseUUID
                )
            }
            workoutExercise.workout = workout
            context.insert(workoutExercise)

            for (index, planned) in templateExercise.orderedSets.enumerated() {
                let set = SetEntry(orderIndex: index, reps: planned.targetReps, weight: planned.targetWeight)
                set.workoutExercise = workoutExercise
                context.insert(set)
            }
        }

        template.lastUsedAt = Date.now
        try? context.save()
        return workout
    }

    @discardableResult
    static func repeatWorkout(_ source: Workout, context: ModelContext) -> Workout {
        let workout = Workout(title: source.title, sourceTemplate: source.sourceTemplate)
        context.insert(workout)

        for sourceExercise in source.orderedExercises {
            let workoutExercise: WorkoutExercise
            if let exercise = sourceExercise.exercise {
                workoutExercise = WorkoutExercise(orderIndex: sourceExercise.orderIndex, exercise: exercise)
            } else {
                workoutExercise = WorkoutExercise(
                    orderIndex: sourceExercise.orderIndex,
                    exerciseName: sourceExercise.exerciseName,
                    exerciseUUID: sourceExercise.exerciseUUID
                )
            }
            workoutExercise.workout = workout
            context.insert(workoutExercise)

            for (index, sourceSet) in sourceExercise.orderedSets.enumerated() {
                let set = SetEntry(
                    orderIndex: index,
                    reps: sourceSet.reps,
                    weight: sourceSet.weight,
                    isWarmup: sourceSet.isWarmup
                )
                set.workoutExercise = workoutExercise
                context.insert(set)
            }
        }

        try? context.save()
        return workout
    }

    @discardableResult
    static func makeTemplate(from workout: Workout, name: String, context: ModelContext) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name)
        context.insert(template)

        for workoutExercise in workout.orderedExercises {
            let templateExercise: TemplateExercise
            if let exercise = workoutExercise.exercise {
                templateExercise = TemplateExercise(orderIndex: workoutExercise.orderIndex, exercise: exercise)
            } else {
                templateExercise = TemplateExercise(
                    orderIndex: workoutExercise.orderIndex,
                    exerciseName: workoutExercise.exerciseName,
                    exerciseUUID: workoutExercise.exerciseUUID
                )
            }
            templateExercise.template = template
            context.insert(templateExercise)

            for (index, set) in workoutExercise.orderedSets.enumerated() {
                let planned = TemplateSet(orderIndex: index, targetReps: set.reps, targetWeight: set.weight)
                planned.templateExercise = templateExercise
                context.insert(planned)
            }
        }

        try? context.save()
        return template
    }

    @discardableResult
    static func addExercise(_ exercise: Exercise, to workout: Workout, context: ModelContext) -> WorkoutExercise {
        let nextIndex = ((workout.exercises ?? []).map(\.orderIndex).max() ?? -1) + 1
        let workoutExercise = WorkoutExercise(orderIndex: nextIndex, exercise: exercise)
        workoutExercise.workout = workout
        context.insert(workoutExercise)
        addSet(to: workoutExercise, context: context)
        return workoutExercise
    }

    /// Adds a set pre-filled from the previous set of the same exercise.
    @discardableResult
    static func addSet(to workoutExercise: WorkoutExercise, context: ModelContext) -> SetEntry {
        let ordered = workoutExercise.orderedSets
        let nextIndex = (ordered.map(\.orderIndex).max() ?? -1) + 1
        let last = ordered.last
        let set = SetEntry(orderIndex: nextIndex, reps: last?.reps ?? 0, weight: last?.weight ?? 0)
        set.workoutExercise = workoutExercise
        context.insert(set)
        return set
    }

    /// Inserts a percent-based warm-up ramp above the working sets, rounded
    /// to the exercise's progression step.
    static func addWarmupRamp(
        to workoutExercise: WorkoutExercise,
        targetWeight: Double,
        step: Double,
        context: ModelContext
    ) {
        guard targetWeight > 0, step > 0 else { return }
        let scheme: [(fraction: Double, reps: Int)] = [(0.4, 10), (0.6, 6), (0.8, 3)]
        var ramp: [(weight: Double, reps: Int)] = []
        for stage in scheme {
            let rounded = max(step, (targetWeight * stage.fraction / step).rounded() * step)
            guard rounded < targetWeight else { continue }
            if ramp.last?.weight == rounded { continue }
            ramp.append((rounded, stage.reps))
        }
        guard !ramp.isEmpty else { return }

        // Recorded efforts key off the set index — shift them in lockstep.
        for effort in efforts(for: workoutExercise, context: context) {
            effort.setOrderIndex += ramp.count
        }
        for (offset, set) in workoutExercise.orderedSets.enumerated() {
            set.orderIndex = ramp.count + offset
        }
        for (index, stage) in ramp.enumerated() {
            let set = SetEntry(orderIndex: index, reps: stage.reps, weight: stage.weight, isWarmup: true)
            set.workoutExercise = workoutExercise
            context.insert(set)
        }
        try? context.save()
    }

    /// Drops sets never ticked off during the session; exercises left with no
    /// sets are removed entirely. Recorded efforts are renumbered/deleted in
    /// lockstep with the sets they describe.
    static func removeIncompleteSets(in workout: Workout, context: ModelContext) {
        for workoutExercise in workout.orderedExercises {
            let ordered = workoutExercise.orderedSets
            let dropped = ordered.filter { !$0.isCompleted }
            guard !dropped.isEmpty else { continue }

            let exerciseEfforts = efforts(for: workoutExercise, context: context)
            let droppedIndexes = Set(dropped.map(\.orderIndex))
            for effort in exerciseEfforts where droppedIndexes.contains(effort.setOrderIndex) {
                context.delete(effort)
            }

            dropped.forEach(context.delete)
            let kept = ordered.filter(\.isCompleted)
            if kept.isEmpty {
                context.delete(workoutExercise)
            } else {
                for (index, set) in kept.enumerated() {
                    if set.orderIndex != index,
                       let effort = exerciseEfforts.first(where: { $0.setOrderIndex == set.orderIndex }) {
                        effort.setOrderIndex = index
                    }
                    set.orderIndex = index
                }
            }
        }
        let remaining = workout.orderedExercises
        for (index, exercise) in remaining.enumerated() {
            exercise.orderIndex = index
        }
        try? context.save()
    }

    /// Deletes a workout together with the RIR efforts recorded for it.
    static func delete(_ workout: Workout, context: ModelContext) {
        let start = workout.startDate
        let descriptor = FetchDescriptor<SetEffort>(
            predicate: #Predicate<SetEffort> { $0.workoutStartDate == start }
        )
        for effort in (try? context.fetch(descriptor)) ?? [] {
            context.delete(effort)
        }
        context.delete(workout)
        try? context.save()
    }

    private static func efforts(for workoutExercise: WorkoutExercise, context: ModelContext) -> [SetEffort] {
        guard let workout = workoutExercise.workout else { return [] }
        let start = workout.startDate
        let uuid: UUID? = workoutExercise.exerciseUUID
        let descriptor = FetchDescriptor<SetEffort>(
            predicate: #Predicate<SetEffort> { $0.workoutStartDate == start && $0.exerciseUUID == uuid }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func finish(_ workout: Workout, context: ModelContext) {
        let end = Date.now
        workout.endDate = end
        workout.durationSeconds = max(0, Int(end.timeIntervalSince(workout.startDate)))
        try? context.save()
        WidgetDataStore.refresh(context: context)
    }
}
