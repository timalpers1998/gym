import Foundation
import SwiftData

/// Writes the entire store plus preferences to a versioned JSON file, and
/// merges such files back in. Restore never deletes anything: rows that
/// already exist locally are skipped, everything else is inserted, so
/// re-importing the same file is a no-op.
@MainActor
enum BackupService {
    /// 1 = v1.6 original; 2 adds measurement, superset groups, set types and
    /// durations — all optional, so either version reads under this decoder.
    static let currentFormatVersion = 2

    /// Matching two dates through a JSON round-trip: encoding keeps
    /// millisecond precision while the store keeps sub-microsecond, so
    /// equality checks use this tolerance instead of ==.
    private static let dateTolerance: TimeInterval = 0.01

    enum BackupError: LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                "This backup uses format version \(version), which this version of the app cannot read."
            }
        }
    }

    // MARK: - Document

    struct BackupDocument: Codable {
        var formatVersion: Int
        var exportedAt: Date
        var exercises: [ExerciseDTO]
        var templates: [TemplateDTO]
        var workouts: [WorkoutDTO]
        var bodyWeight: [BodyWeightDTO]
        var efforts: [EffortDTO]
        var settings: SettingsDTO?
    }

    struct ExerciseDTO: Codable {
        var uuid: UUID
        var name: String
        var muscleGroupRaw: String
        var equipmentRaw: String
        var isCustom: Bool
        var isArchived: Bool
        var notes: String
        var createdAt: Date
        var measurementRaw: String?
    }

    struct TemplateDTO: Codable {
        var name: String
        var notes: String
        var createdAt: Date
        var lastUsedAt: Date?
        var exercises: [TemplateExerciseDTO]
    }

    struct TemplateExerciseDTO: Codable {
        var orderIndex: Int
        var exerciseName: String
        var exerciseUUID: UUID?
        var supersetGroup: Int?
        var sets: [TemplateSetDTO]
    }

    struct TemplateSetDTO: Codable {
        var orderIndex: Int
        var targetReps: Int
        var targetWeight: Double
        var targetDurationSeconds: Int?
    }

    struct WorkoutDTO: Codable {
        var title: String
        var notes: String
        var startDate: Date
        var endDate: Date?
        var durationSeconds: Int
        var sourceTemplateName: String?
        var exercises: [WorkoutExerciseDTO]
    }

    struct WorkoutExerciseDTO: Codable {
        var orderIndex: Int
        var exerciseName: String
        var exerciseUUID: UUID?
        var notes: String
        var supersetGroup: Int?
        var sets: [SetDTO]
    }

    struct SetDTO: Codable {
        var orderIndex: Int
        var reps: Int
        var weight: Double
        var isCompleted: Bool
        var completedAt: Date?
        var isWarmup: Bool
        var typeRaw: String?
        var durationSeconds: Int?
    }

    struct BodyWeightDTO: Codable {
        var date: Date
        var weightKg: Double
    }

    struct EffortDTO: Codable {
        var workoutStartDate: Date
        var exerciseUUID: UUID?
        var setOrderIndex: Int
        var rir: Int
    }

    struct SettingsDTO: Codable {
        var weightUnitRaw: String
        var restDurationSeconds: Int
        var autoStartRestTimer: Bool
        var barWeight: Double
        var progressionSteps: [String: Double]
        var restDurationOverrides: [String: Int]
    }

    struct ImportSummary {
        var exercisesAdded = 0
        var templatesAdded = 0
        var workoutsAdded = 0
        var bodyWeightAdded = 0
        var effortsAdded = 0
        var skipped = 0
        var settingsApplied = false
    }

    // MARK: - Export

    static func export(context: ModelContext, settings: AppSettings) throws -> URL {
        let exercises = try context.fetch(
            FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        )
        let templates = try context.fetch(
            FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.name)])
        )
        let workouts = try context.fetch(
            FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.startDate)])
        )
        let bodyWeight = try context.fetch(
            FetchDescriptor<BodyWeightEntry>(sortBy: [SortDescriptor(\.date)])
        )
        let efforts = try context.fetch(
            FetchDescriptor<SetEffort>(sortBy: [SortDescriptor(\.workoutStartDate)])
        )

        let document = BackupDocument(
            formatVersion: currentFormatVersion,
            exportedAt: .now,
            exercises: exercises.map { exercise in
                ExerciseDTO(
                    uuid: exercise.uuid,
                    name: exercise.name,
                    muscleGroupRaw: exercise.muscleGroupRaw,
                    equipmentRaw: exercise.equipmentRaw,
                    isCustom: exercise.isCustom,
                    isArchived: exercise.isArchived,
                    notes: exercise.notes,
                    createdAt: exercise.createdAt,
                    measurementRaw: exercise.measurementRaw
                )
            },
            templates: templates.map { template in
                TemplateDTO(
                    name: template.name,
                    notes: template.notes,
                    createdAt: template.createdAt,
                    lastUsedAt: template.lastUsedAt,
                    exercises: template.orderedExercises.map { templateExercise in
                        TemplateExerciseDTO(
                            orderIndex: templateExercise.orderIndex,
                            exerciseName: templateExercise.exerciseName,
                            exerciseUUID: templateExercise.exerciseUUID,
                            supersetGroup: templateExercise.supersetGroup,
                            sets: templateExercise.orderedSets.map { set in
                                TemplateSetDTO(
                                    orderIndex: set.orderIndex,
                                    targetReps: set.targetReps,
                                    targetWeight: set.targetWeight,
                                    targetDurationSeconds: set.targetDurationSeconds
                                )
                            }
                        )
                    }
                )
            },
            workouts: workouts.map { workout in
                WorkoutDTO(
                    title: workout.title,
                    notes: workout.notes,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    durationSeconds: workout.durationSeconds,
                    sourceTemplateName: workout.sourceTemplate?.name,
                    exercises: workout.orderedExercises.map { workoutExercise in
                        WorkoutExerciseDTO(
                            orderIndex: workoutExercise.orderIndex,
                            exerciseName: workoutExercise.exerciseName,
                            exerciseUUID: workoutExercise.exerciseUUID,
                            notes: workoutExercise.notes,
                            supersetGroup: workoutExercise.supersetGroup,
                            sets: workoutExercise.orderedSets.map { set in
                                SetDTO(
                                    orderIndex: set.orderIndex,
                                    reps: set.reps,
                                    weight: set.weight,
                                    isCompleted: set.isCompleted,
                                    completedAt: set.completedAt,
                                    isWarmup: set.isWarmup,
                                    typeRaw: set.typeRaw,
                                    durationSeconds: set.durationSeconds
                                )
                            }
                        )
                    }
                )
            },
            bodyWeight: bodyWeight.map { BodyWeightDTO(date: $0.date, weightKg: $0.weightKg) },
            efforts: efforts.map { effort in
                EffortDTO(
                    workoutStartDate: effort.workoutStartDate,
                    exerciseUUID: effort.exerciseUUID,
                    setOrderIndex: effort.setOrderIndex,
                    rir: effort.rir
                )
            },
            settings: SettingsDTO(
                weightUnitRaw: settings.weightUnitRaw,
                restDurationSeconds: settings.restDurationSeconds,
                autoStartRestTimer: settings.autoStartRestTimer,
                barWeight: settings.barWeight,
                progressionSteps: settings.progressionSteps,
                restDurationOverrides: settings.restDurationOverrides
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.encodingFormatter.string(from: date))
        }
        let data = try encoder.encode(document)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymTracker-Backup-\(fileNameFormatter.string(from: .now)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    static func importBackup(
        from url: URL,
        context: ModelContext,
        settings: AppSettings
    ) throws -> ImportSummary {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.encodingFormatter.date(from: string)
                ?? Self.plainFormatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unrecognized date: \(string)"
            ))
        }
        let document = try decoder.decode(BackupDocument.self, from: data)

        guard document.formatVersion <= currentFormatVersion else {
            throw BackupError.unsupportedVersion(document.formatVersion)
        }

        var summary = ImportSummary()

        // Exercises first, building a map from backup UUID to local exercise.
        // Built-in exercises share fixed seed UUIDs across installs; name
        // matching catches the rest (e.g. a custom exercise recreated by hand).
        var localExercises = try context.fetch(FetchDescriptor<Exercise>())
        var uuidRemap: [UUID: UUID] = [:]
        var exercisesByUUID: [UUID: Exercise] = [:]
        for exercise in localExercises {
            exercisesByUUID[exercise.uuid] = exercise
        }

        for dto in document.exercises {
            let resolved: Exercise
            if let match = exercisesByUUID[dto.uuid] {
                resolved = match
            } else if let match = localExercises.first(where: {
                normalized($0.name) == normalized(dto.name)
            }) {
                resolved = match
            } else {
                let exercise = Exercise(
                    uuid: dto.uuid,
                    name: dto.name,
                    muscleGroup: MuscleGroup(rawValue: dto.muscleGroupRaw) ?? .other,
                    equipment: Equipment(rawValue: dto.equipmentRaw) ?? .other,
                    isCustom: dto.isCustom,
                    notes: dto.notes,
                    measurement: dto.measurementRaw.flatMap(ExerciseMeasurement.init) ?? .reps
                )
                exercise.isArchived = dto.isArchived
                exercise.createdAt = dto.createdAt
                context.insert(exercise)
                localExercises.append(exercise)
                exercisesByUUID[exercise.uuid] = exercise
                summary.exercisesAdded += 1
                resolved = exercise
            }
            uuidRemap[dto.uuid] = resolved.uuid
        }

        func remap(_ uuid: UUID?) -> UUID? {
            guard let uuid else { return nil }
            return uuidRemap[uuid] ?? uuid
        }

        func exercise(for uuid: UUID?) -> Exercise? {
            guard let uuid else { return nil }
            return exercisesByUUID[uuid]
        }

        // Templates, deduplicated by name.
        var templatesByName: [String: WorkoutTemplate] = [:]
        for template in try context.fetch(FetchDescriptor<WorkoutTemplate>()) {
            templatesByName[normalized(template.name)] = template
        }

        for dto in document.templates {
            guard templatesByName[normalized(dto.name)] == nil else {
                summary.skipped += 1
                continue
            }
            let template = WorkoutTemplate(name: dto.name, notes: dto.notes)
            template.createdAt = dto.createdAt
            template.lastUsedAt = dto.lastUsedAt
            context.insert(template)
            templatesByName[normalized(dto.name)] = template

            for exerciseDTO in dto.exercises {
                let mappedUUID = remap(exerciseDTO.exerciseUUID)
                let templateExercise: TemplateExercise
                if let exercise = exercise(for: mappedUUID) {
                    templateExercise = TemplateExercise(
                        orderIndex: exerciseDTO.orderIndex, exercise: exercise
                    )
                } else {
                    templateExercise = TemplateExercise(
                        orderIndex: exerciseDTO.orderIndex,
                        exerciseName: exerciseDTO.exerciseName,
                        exerciseUUID: mappedUUID
                    )
                }
                templateExercise.supersetGroup = exerciseDTO.supersetGroup
                templateExercise.template = template
                context.insert(templateExercise)

                for setDTO in exerciseDTO.sets {
                    let planned = TemplateSet(
                        orderIndex: setDTO.orderIndex,
                        targetReps: setDTO.targetReps,
                        targetWeight: setDTO.targetWeight,
                        targetDurationSeconds: setDTO.targetDurationSeconds ?? 0
                    )
                    planned.templateExercise = templateExercise
                    context.insert(planned)
                }
            }
            summary.templatesAdded += 1
        }

        // Workouts, deduplicated by (startDate, title). Records where each
        // backup workout landed so effort rows can point at the exact stored
        // start date, which their lookups compare with ==.
        let localWorkouts = try context.fetch(FetchDescriptor<Workout>())
        var workoutDateRemap: [Date: Date] = [:]

        for dto in document.workouts {
            if let existing = localWorkouts.first(where: {
                abs($0.startDate.timeIntervalSince(dto.startDate)) < dateTolerance
                    && $0.title == dto.title
            }) {
                workoutDateRemap[dto.startDate] = existing.startDate
                summary.skipped += 1
                continue
            }

            let workout = Workout(
                title: dto.title,
                startDate: dto.startDate,
                sourceTemplate: dto.sourceTemplateName.flatMap { templatesByName[normalized($0)] }
            )
            workout.notes = dto.notes
            // Never import a second "active" session — the Workout tab treats
            // endDate == nil as the live workout. Close unfinished ones at
            // their last completed set.
            let endDate = dto.endDate
                ?? dto.exercises.flatMap(\.sets).compactMap(\.completedAt).max()
                ?? dto.startDate
            workout.endDate = endDate
            workout.durationSeconds = dto.durationSeconds > 0
                ? dto.durationSeconds
                : max(0, Int(endDate.timeIntervalSince(dto.startDate)))
            context.insert(workout)
            workoutDateRemap[dto.startDate] = dto.startDate

            for exerciseDTO in dto.exercises {
                let mappedUUID = remap(exerciseDTO.exerciseUUID)
                let workoutExercise: WorkoutExercise
                if let exercise = exercise(for: mappedUUID) {
                    workoutExercise = WorkoutExercise(
                        orderIndex: exerciseDTO.orderIndex, exercise: exercise
                    )
                } else {
                    workoutExercise = WorkoutExercise(
                        orderIndex: exerciseDTO.orderIndex,
                        exerciseName: exerciseDTO.exerciseName,
                        exerciseUUID: mappedUUID
                    )
                }
                workoutExercise.notes = exerciseDTO.notes
                workoutExercise.supersetGroup = exerciseDTO.supersetGroup
                workoutExercise.workout = workout
                context.insert(workoutExercise)

                for setDTO in exerciseDTO.sets {
                    let set = SetEntry(
                        orderIndex: setDTO.orderIndex,
                        reps: setDTO.reps,
                        weight: setDTO.weight,
                        isWarmup: setDTO.isWarmup,
                        type: setDTO.typeRaw.flatMap(SetType.init) ?? .working,
                        durationSeconds: setDTO.durationSeconds ?? 0
                    )
                    set.isCompleted = setDTO.isCompleted
                    set.completedAt = setDTO.completedAt
                    set.workoutExercise = workoutExercise
                    context.insert(set)
                }
            }
            summary.workoutsAdded += 1
        }

        // Body weight, deduplicated by (date, weight).
        let localBodyWeight = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        for dto in document.bodyWeight {
            if localBodyWeight.contains(where: {
                abs($0.date.timeIntervalSince(dto.date)) < dateTolerance
                    && abs($0.weightKg - dto.weightKg) < 0.001
            }) {
                summary.skipped += 1
                continue
            }
            context.insert(BodyWeightEntry(date: dto.date, weightKg: dto.weightKg))
            summary.bodyWeightAdded += 1
        }

        // RIR efforts, remapped onto the resolved workout dates and exercise
        // UUIDs, deduplicated by (workout, exercise, set index).
        let localEfforts = try context.fetch(FetchDescriptor<SetEffort>())
        for dto in document.efforts {
            let date = workoutDateRemap[dto.workoutStartDate] ?? dto.workoutStartDate
            let mappedUUID = remap(dto.exerciseUUID)
            if localEfforts.contains(where: {
                abs($0.workoutStartDate.timeIntervalSince(date)) < dateTolerance
                    && $0.exerciseUUID == mappedUUID
                    && $0.setOrderIndex == dto.setOrderIndex
            }) {
                summary.skipped += 1
                continue
            }
            context.insert(SetEffort(
                workoutStartDate: date,
                exerciseUUID: mappedUUID,
                setOrderIndex: dto.setOrderIndex,
                rir: dto.rir
            ))
            summary.effortsAdded += 1
        }

        if let dto = document.settings {
            if WeightUnit(rawValue: dto.weightUnitRaw) != nil {
                settings.weightUnitRaw = dto.weightUnitRaw
            }
            settings.restDurationSeconds = min(max(dto.restDurationSeconds, 15), 600)
            settings.autoStartRestTimer = dto.autoStartRestTimer
            settings.barWeight = dto.barWeight

            // The per-exercise override dictionaries are keyed by exercise
            // UUID strings, so keys follow the same remap as the rows they
            // describe; local overrides win on collision (merge, not replace).
            func remapKeys<Value>(_ dict: [String: Value]) -> [String: Value] {
                Dictionary(
                    dict.map { key, value in
                        (UUID(uuidString: key).flatMap { uuidRemap[$0] }?.uuidString ?? key, value)
                    },
                    uniquingKeysWith: { first, _ in first }
                )
            }
            settings.progressionSteps = remapKeys(dto.progressionSteps)
                .merging(settings.progressionSteps) { _, local in local }
            settings.restDurationOverrides = remapKeys(dto.restDurationOverrides)
                .merging(settings.restDurationOverrides) { _, local in local }
            summary.settingsApplied = true
        }

        try context.save()
        return summary
    }

    // MARK: - Helpers

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Millisecond precision so workout dates and the effort rows keyed to
    /// them stay equal through a round-trip.
    private static let encodingFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
