import SwiftUI
import SwiftData

/// Plain-value copy of a previous session's set. Snapshotting (instead of
/// holding SetEntry references) keeps the hints safe to render even if the
/// source workout is deleted from History mid-session.
struct LastSetSnapshot {
    let weight: Double
    let reps: Int
    let isCompleted: Bool
    let isWarmup: Bool
    /// Reps in reserve recorded for the set last session, if any.
    var rir: Int? = nil
}

struct WorkoutExerciseSection: View {
    let workoutExercise: WorkoutExercise

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    /// The same exercise's sets from the most recent finished workout,
    /// used for the "last time" header line and field placeholders.
    @State private var lastSets: [LastSetSnapshot] = []

    /// RIR recorded this session, keyed by set orderIndex.
    @State private var rirBySetIndex: [Int: Int] = [:]

    /// Start of the most recent previous session with this exercise.
    @State private var lastWorkoutDate: Date? = nil

    /// Start of the most recent finished workout overall.
    @State private var overallLastWorkoutDate: Date? = nil

    /// True when the best est. 10RM has been flat or falling for three sessions.
    @State private var stalled = false

    var body: some View {
        Section {
            ForEach(workoutExercise.orderedSets) { set in
                SetRowView(
                    set: set,
                    lastSet: lastSet(for: set),
                    suggestion: suggestion(for: set),
                    rir: rirBySetIndex[set.orderIndex],
                    onSelectRIR: { value in
                        setRIR(value, for: set)
                    }
                )
            }
            .onDelete { offsets in
                deleteSets(at: offsets)
            }

            Button {
                WorkoutFactory.addSet(to: workoutExercise, context: context)
            } label: {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.subheadline)
            }
        } header: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutExercise.exerciseName)
                    if let lastSummary {
                        Text(lastSummary)
                            .font(.caption2)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Menu {
                    if let uuid = workoutExercise.exerciseUUID {
                        progressionStepPicker(uuid: uuid)
                        restDurationPicker(uuid: uuid)
                    }
                    if canGenerateWarmups {
                        Button {
                            generateWarmups()
                        } label: {
                            Label("Generate Warm-ups", systemImage: "flame")
                        }
                    }
                    Button {
                        moveExercise(by: -1)
                    } label: {
                        Label("Move Up", systemImage: "arrow.up")
                    }
                    .disabled(isFirstExercise)
                    Button {
                        moveExercise(by: 1)
                    } label: {
                        Label("Move Down", systemImage: "arrow.down")
                    }
                    .disabled(isLastExercise)
                    Button(role: .destructive) {
                        removeExercise()
                    } label: {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadLastSets()
            loadEfforts()
        }
    }

    private var lastSummary: String? {
        let completed = lastSets.filter(\.isCompleted)
        guard !completed.isEmpty else { return nil }
        let sets = completed
            .map { "\(Format.plainWeight($0.weight))×\($0.reps)" }
            .joined(separator: " · ")
        return "Last: \(sets)"
    }

    /// Pairs the nth working set with last session's nth working set (and
    /// warm-ups with warm-ups), so differing warm-up counts between sessions
    /// don't misalign the hints.
    private func lastSet(for set: SetEntry) -> LastSetSnapshot? {
        let peers = workoutExercise.orderedSets.filter { $0.isWarmup == set.isWarmup }
        guard let position = peers.firstIndex(where: { $0 === set }) else { return nil }
        let lastPeers = lastSets.filter { $0.isWarmup == set.isWarmup }
        guard position < lastPeers.count else { return nil }
        return lastPeers[position]
    }

    private func progressionStepPicker(uuid: UUID) -> some View {
        let choices: [Double] = settings.weightUnit == .lb
            ? [1, 2.5, 5, 10]
            : [0.5, 1, 1.25, 2.5, 5]
        return Picker(selection: Binding(
            get: { settings.progressionStep(for: uuid) },
            set: { settings.setProgressionStep($0, for: uuid) }
        )) {
            ForEach(choices, id: \.self) { step in
                Text("\(Format.plainWeight(step)) \(settings.weightUnit.displayName)").tag(step)
            }
        } label: {
            Label("Progression Step", systemImage: "chart.line.uptrend.xyaxis")
        }
        .pickerStyle(.menu)
    }

    private func restDurationPicker(uuid: UUID) -> some View {
        Picker(selection: Binding(
            get: { settings.restDurationOverrides[uuid.uuidString] ?? 0 },
            set: { settings.setRestDuration($0 == 0 ? nil : $0, for: uuid) }
        )) {
            Text("Default (\(Format.timerCountdown(seconds: settings.restDurationSeconds)))").tag(0)
            ForEach([60, 90, 120, 150, 180, 240], id: \.self) { seconds in
                Text(Format.timerCountdown(seconds: seconds)).tag(seconds)
            }
        } label: {
            Label("Rest Timer", systemImage: "timer")
        }
        .pickerStyle(.menu)
    }

    private var isFirstExercise: Bool {
        workoutExercise.workout?.orderedExercises.first === workoutExercise
    }

    private var isLastExercise: Bool {
        workoutExercise.workout?.orderedExercises.last === workoutExercise
    }

    private func moveExercise(by delta: Int) {
        guard let workout = workoutExercise.workout else { return }
        let ordered = workout.orderedExercises
        guard let index = ordered.firstIndex(where: { $0 === workoutExercise }) else { return }
        let target = index + delta
        guard target >= 0 && target < ordered.count else { return }
        let other = ordered[target]
        let ownIndex = workoutExercise.orderIndex
        workoutExercise.orderIndex = other.orderIndex
        other.orderIndex = ownIndex
    }

    /// Offered until the exercise has warm-up sets, once a target weight is known.
    private var canGenerateWarmups: Bool {
        !workoutExercise.orderedSets.contains(where: \.isWarmup) && warmupTargetWeight > 0
    }

    private var warmupTargetWeight: Double {
        if let firstWorking = workoutExercise.orderedSets.first(where: { !$0.isWarmup }),
           firstWorking.weight > 0 {
            return firstWorking.weight
        }
        return lastSets.first(where: { !$0.isWarmup && $0.isCompleted })?.weight ?? 0
    }

    private func generateWarmups() {
        WorkoutFactory.addWarmupRamp(
            to: workoutExercise,
            targetWeight: warmupTargetWeight,
            step: settings.progressionStep(for: workoutExercise.exerciseUUID),
            context: context
        )
        // Set indexes shifted; re-sync the recorded-effort cache.
        loadEfforts()
    }

    /// Target for the next pending working set: the smallest estimated-10RM
    /// increase over last session's corresponding set. Other rows get nil.
    private func suggestion(for set: SetEntry) -> ProgressionSuggestion? {
        guard !set.isCompleted, !set.isWarmup else { return nil }
        guard let current = workoutExercise.orderedSets.first(where: { !$0.isCompleted && !$0.isWarmup }),
              current === set else { return nil }
        guard let baseline = lastSet(for: set),
              baseline.isCompleted, !baseline.isWarmup, baseline.reps > 0 else { return nil }
        let step = settings.progressionStep(for: workoutExercise.exerciseUUID)

        if let overall = overallLastWorkoutDate,
           Date.now.timeIntervalSince(overall) > 14 * 86_400,
           let comeback = ProgressionCalculator.comeback(
               lastWeight: baseline.weight, lastReps: baseline.reps, step: step
           ) {
            return comeback
        }
        if stalled,
           let deload = ProgressionCalculator.deload(
               lastWeight: baseline.weight, lastReps: baseline.reps, step: step
           ) {
            return deload
        }

        // An easy last session (3+ reps in reserve) skips a progression step:
        // suggest as if last session had already been one step heavier.
        let allow = allowIncrease(before: set)
        let easy = allow && (baseline.rir ?? 0) >= 3 && baseline.weight > 0
        return ProgressionCalculator.nextProgression(
            lastWeight: easy ? baseline.weight + step : baseline.weight,
            lastReps: baseline.reps,
            increment: step,
            allowIncrease: allow
        )
    }

    /// A completed set this session that fell short of its own last-session
    /// baseline holds the next target at last session's numbers.
    private func allowIncrease(before set: SetEntry) -> Bool {
        let previous = workoutExercise.orderedSets
            .filter { $0.isCompleted && !$0.isWarmup && $0.orderIndex < set.orderIndex }
            .max { $0.orderIndex < $1.orderIndex }
        guard let previous else { return true }
        // A set taken to failure this session means no added load on the next.
        if rirBySetIndex[previous.orderIndex] == 0 { return false }
        guard let baseline = lastSet(for: previous),
              baseline.isCompleted, !baseline.isWarmup, baseline.reps > 0 else { return true }
        if baseline.weight <= 0 {
            return previous.reps >= baseline.reps
        }
        let achieved = ProgressionCalculator.estimatedTenRepMax(weight: previous.weight, reps: previous.reps)
        let target = ProgressionCalculator.estimatedTenRepMax(weight: baseline.weight, reps: baseline.reps)
        return achieved >= target - 0.05
    }

    private func loadLastSets() {
        guard let uuid = workoutExercise.exerciseUUID else { return }
        let id: UUID? = uuid
        let descriptor = FetchDescriptor<WorkoutExercise>(
            predicate: #Predicate<WorkoutExercise> { $0.exerciseUUID == id }
        )
        guard let entries = try? context.fetch(descriptor) else { return }

        let currentWorkout = workoutExercise.workout
        let history = entries
            .filter { $0.workout?.endDate != nil && $0.workout !== currentWorkout }
            .sorted { ($0.workout?.startDate ?? .distantPast) > ($1.workout?.startDate ?? .distantPast) }

        let previous = history.first
        lastWorkoutDate = previous?.workout?.startDate

        var lastEfforts: [Int: Int] = [:]
        if let previousStart = previous?.workout?.startDate {
            let effortDescriptor = FetchDescriptor<SetEffort>(
                predicate: #Predicate<SetEffort> {
                    $0.workoutStartDate == previousStart && $0.exerciseUUID == id
                }
            )
            for effort in (try? context.fetch(effortDescriptor)) ?? [] {
                lastEfforts[effort.setOrderIndex] = effort.rir
            }
        }

        lastSets = (previous?.orderedSets ?? []).map { set in
            LastSetSnapshot(
                weight: set.weight,
                reps: set.reps,
                isCompleted: set.isCompleted,
                isWarmup: set.isWarmup,
                rir: lastEfforts[set.orderIndex]
            )
        }

        // Plateau: best est. 10RM flat (within tolerance) across three
        // sessions. The 0.92 floors on BOTH transitions keep a single heavy
        // outlier day or a recent deload from reading as a plateau.
        let bests = history.prefix(3).map(sessionBestTenRM)
        stalled = bests.count >= 3
            && bests.allSatisfy { $0 > 0 }
            && bests[0] <= bests[1] + 0.25
            && bests[1] <= bests[2] + 0.25
            && bests[0] >= bests[1] * 0.92
            && bests[1] >= bests[2] * 0.92

        // Overall last training day (any exercise) drives the comeback gate,
        // so an accessory rotated on a long cycle isn't treated as a layoff.
        var overallDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endDate != nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        overallDescriptor.fetchLimit = 1
        overallLastWorkoutDate = (try? context.fetch(overallDescriptor))?.first?.startDate
    }

    private func sessionBestTenRM(_ entry: WorkoutExercise) -> Double {
        entry.orderedSets
            .filter { $0.isCompleted && !$0.isWarmup && $0.reps > 0 && $0.weight > 0 }
            .map { ProgressionCalculator.estimatedTenRepMax(weight: $0.weight, reps: $0.reps) }
            .max() ?? 0
    }

    private func loadEfforts() {
        guard let workout = workoutExercise.workout else { return }
        let start = workout.startDate
        let uuid: UUID? = workoutExercise.exerciseUUID
        let descriptor = FetchDescriptor<SetEffort>(
            predicate: #Predicate<SetEffort> {
                $0.workoutStartDate == start && $0.exerciseUUID == uuid
            }
        )
        let efforts = (try? context.fetch(descriptor)) ?? []
        rirBySetIndex = Dictionary(
            efforts.map { ($0.setOrderIndex, $0.rir) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func setRIR(_ value: Int, for set: SetEntry) {
        guard let workout = workoutExercise.workout else { return }
        let start = workout.startDate
        let uuid: UUID? = workoutExercise.exerciseUUID
        let index = set.orderIndex
        let descriptor = FetchDescriptor<SetEffort>(
            predicate: #Predicate<SetEffort> {
                $0.workoutStartDate == start && $0.exerciseUUID == uuid && $0.setOrderIndex == index
            }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.rir = value
        } else {
            let effort = SetEffort(
                workoutStartDate: start,
                exerciseUUID: uuid,
                setOrderIndex: index,
                rir: value
            )
            context.insert(effort)
        }
        try? context.save()
        rirBySetIndex[index] = value
    }

    private func deleteSets(at offsets: IndexSet) {
        WorkoutFactory.deleteSets(at: offsets, from: workoutExercise, context: context)
        loadEfforts()
    }

    private func removeExercise() {
        WorkoutFactory.deleteEfforts(for: workoutExercise, context: context)
        guard let workout = workoutExercise.workout else {
            context.delete(workoutExercise)
            return
        }
        context.delete(workoutExercise)
        let remaining = workout.orderedExercises.filter { $0 !== workoutExercise }
        for (index, exercise) in remaining.enumerated() {
            exercise.orderIndex = index
        }
    }
}
