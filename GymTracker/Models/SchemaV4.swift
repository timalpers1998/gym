import Foundation
import SwiftData

/// V4 is the first version to redefine the core model classes (V1's are
/// checksum-frozen and remain untouched for migration). All new properties
/// have defaults, so V3 → V4 is a lightweight migration:
/// - Exercise.measurementRaw — reps × weight vs. duration logging
/// - WorkoutExercise.supersetGroup / TemplateExercise.supersetGroup —
///   exercises sharing a non-nil value form a superset
/// - SetEntry.typeRaw — working / drop set / failure / AMRAP
/// - SetEntry.durationSeconds / TemplateSet.targetDurationSeconds — timed sets
enum GymSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            TemplateSet.self,
            Workout.self,
            WorkoutExercise.self,
            SetEntry.self,
            GymSchemaV2.BodyWeightEntry.self,
            GymSchemaV3.SetEffort.self,
        ]
    }
}

extension GymSchemaV4 {
    @Model
    final class Exercise {
        var uuid: UUID = UUID()
        var name: String = ""
        var muscleGroupRaw: String = MuscleGroup.other.rawValue
        var equipmentRaw: String = Equipment.other.rawValue
        var isCustom: Bool = false
        var isArchived: Bool = false
        var notes: String = ""
        var createdAt: Date = Date.now
        var measurementRaw: String = ExerciseMeasurement.reps.rawValue

        @Relationship(deleteRule: .nullify, inverse: \TemplateExercise.exercise)
        var templateExercises: [TemplateExercise]? = nil

        @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
        var workoutExercises: [WorkoutExercise]? = nil

        var muscleGroup: MuscleGroup {
            get { MuscleGroup(rawValue: muscleGroupRaw) ?? .other }
            set { muscleGroupRaw = newValue.rawValue }
        }

        var equipment: Equipment {
            get { Equipment(rawValue: equipmentRaw) ?? .other }
            set { equipmentRaw = newValue.rawValue }
        }

        var measurement: ExerciseMeasurement {
            get { ExerciseMeasurement(rawValue: measurementRaw) ?? .reps }
            set { measurementRaw = newValue.rawValue }
        }

        init(
            uuid: UUID = UUID(),
            name: String,
            muscleGroup: MuscleGroup,
            equipment: Equipment = .other,
            isCustom: Bool = false,
            notes: String = "",
            measurement: ExerciseMeasurement = .reps
        ) {
            self.uuid = uuid
            self.name = name
            self.muscleGroupRaw = muscleGroup.rawValue
            self.equipmentRaw = equipment.rawValue
            self.isCustom = isCustom
            self.notes = notes
            self.createdAt = Date.now
            self.measurementRaw = measurement.rawValue
        }
    }

    @Model
    final class WorkoutTemplate {
        var name: String = ""
        var notes: String = ""
        var createdAt: Date = Date.now
        var lastUsedAt: Date? = nil

        @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
        var exercises: [TemplateExercise]? = nil

        @Relationship(deleteRule: .nullify, inverse: \Workout.sourceTemplate)
        var workouts: [Workout]? = nil

        var orderedExercises: [TemplateExercise] {
            (exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }

        /// Distinct superset group values in exercise order, for stable
        /// A/B/C labeling.
        var supersetGroups: [Int] {
            var seen: [Int] = []
            for exercise in orderedExercises {
                if let group = exercise.supersetGroup, !seen.contains(group) {
                    seen.append(group)
                }
            }
            return seen
        }

        func supersetLabel(for group: Int) -> String? {
            GymSchemaV4.supersetLabel(for: group, in: supersetGroups)
        }

        init(name: String, notes: String = "") {
            self.name = name
            self.notes = notes
            self.createdAt = Date.now
        }
    }

    @Model
    final class TemplateExercise {
        var orderIndex: Int = 0
        var exerciseName: String = ""
        var exerciseUUID: UUID? = nil
        var supersetGroup: Int? = nil
        var exercise: Exercise? = nil
        var template: WorkoutTemplate? = nil

        @Relationship(deleteRule: .cascade, inverse: \TemplateSet.templateExercise)
        var plannedSets: [TemplateSet]? = nil

        var orderedSets: [TemplateSet] {
            (plannedSets ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }

        init(orderIndex: Int, exercise: Exercise) {
            self.orderIndex = orderIndex
            self.exercise = exercise
            self.exerciseName = exercise.name
            self.exerciseUUID = exercise.uuid
        }

        init(orderIndex: Int, exerciseName: String, exerciseUUID: UUID?) {
            self.orderIndex = orderIndex
            self.exerciseName = exerciseName
            self.exerciseUUID = exerciseUUID
        }
    }

    @Model
    final class TemplateSet {
        var orderIndex: Int = 0
        var targetReps: Int = 10
        var targetWeight: Double = 0
        var targetDurationSeconds: Int = 0
        var templateExercise: TemplateExercise? = nil

        init(orderIndex: Int, targetReps: Int = 10, targetWeight: Double = 0, targetDurationSeconds: Int = 0) {
            self.orderIndex = orderIndex
            self.targetReps = targetReps
            self.targetWeight = targetWeight
            self.targetDurationSeconds = targetDurationSeconds
        }
    }

    @Model
    final class Workout {
        var startDate: Date = Date.now
        var endDate: Date? = nil
        var durationSeconds: Int = 0
        var title: String = "Workout"
        var notes: String = ""
        var sourceTemplate: WorkoutTemplate? = nil

        @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
        var exercises: [WorkoutExercise]? = nil

        var orderedExercises: [WorkoutExercise] {
            (exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }

        var isActive: Bool { endDate == nil }

        var completedSetCount: Int {
            (exercises ?? []).reduce(0) { count, exercise in
                count + (exercise.sets ?? []).filter(\.isCompleted).count
            }
        }

        var totalVolume: Double {
            (exercises ?? []).reduce(0) { $0 + $1.totalVolume }
        }

        /// Distinct superset group values in exercise order, for stable
        /// A/B/C labeling.
        var supersetGroups: [Int] {
            var seen: [Int] = []
            for exercise in orderedExercises {
                if let group = exercise.supersetGroup, !seen.contains(group) {
                    seen.append(group)
                }
            }
            return seen
        }

        func supersetLabel(for group: Int) -> String? {
            GymSchemaV4.supersetLabel(for: group, in: supersetGroups)
        }

        init(title: String = "Workout", startDate: Date = Date.now, sourceTemplate: WorkoutTemplate? = nil) {
            self.title = title
            self.startDate = startDate
            self.sourceTemplate = sourceTemplate
        }
    }

    @Model
    final class WorkoutExercise {
        var orderIndex: Int = 0
        var exerciseName: String = ""
        var exerciseUUID: UUID? = nil
        var notes: String = ""
        var supersetGroup: Int? = nil
        var exercise: Exercise? = nil
        var workout: Workout? = nil

        @Relationship(deleteRule: .cascade, inverse: \SetEntry.workoutExercise)
        var sets: [SetEntry]? = nil

        var orderedSets: [SetEntry] {
            (sets ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }

        var completedSets: [SetEntry] {
            (sets ?? []).filter(\.isCompleted)
        }

        /// Completed working sets only, matching how ProgressCalculator counts.
        var totalVolume: Double {
            completedSets.filter { !$0.isWarmup }.reduce(0) { $0 + $1.volume }
        }

        /// How this exercise's sets are logged; falls back to reps × weight
        /// when the library row was deleted.
        var measurement: ExerciseMeasurement {
            exercise?.measurement ?? .reps
        }

        init(orderIndex: Int, exercise: Exercise) {
            self.orderIndex = orderIndex
            self.exercise = exercise
            self.exerciseName = exercise.name
            self.exerciseUUID = exercise.uuid
        }

        init(orderIndex: Int, exerciseName: String, exerciseUUID: UUID?) {
            self.orderIndex = orderIndex
            self.exerciseName = exerciseName
            self.exerciseUUID = exerciseUUID
        }
    }

    @Model
    final class SetEntry {
        var orderIndex: Int = 0
        var reps: Int = 0
        var weight: Double = 0
        var isCompleted: Bool = false
        var completedAt: Date? = nil
        var isWarmup: Bool = false
        var typeRaw: String = SetType.working.rawValue
        var durationSeconds: Int = 0
        var workoutExercise: WorkoutExercise? = nil

        var volume: Double { Double(reps) * weight }

        var type: SetType {
            get { SetType(rawValue: typeRaw) ?? .working }
            set { typeRaw = newValue.rawValue }
        }

        init(
            orderIndex: Int,
            reps: Int = 0,
            weight: Double = 0,
            isWarmup: Bool = false,
            type: SetType = .working,
            durationSeconds: Int = 0
        ) {
            self.orderIndex = orderIndex
            self.reps = reps
            self.weight = weight
            self.isWarmup = isWarmup
            self.typeRaw = type.rawValue
            self.durationSeconds = durationSeconds
        }
    }

    private static func supersetLabel(for group: Int, in groups: [Int]) -> String? {
        guard let index = groups.firstIndex(of: group) else { return nil }
        let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
        return "Superset \(index < letters.count ? letters[index] : "\(index + 1)")"
    }
}

/// Shared superset plumbing for live and template exercises.
protocol SupersetMember: AnyObject {
    var supersetGroup: Int? { get set }
}

extension GymSchemaV4.WorkoutExercise: SupersetMember {}
extension GymSchemaV4.TemplateExercise: SupersetMember {}
