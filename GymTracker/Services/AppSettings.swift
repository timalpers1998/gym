import Foundation
import Observation

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg
    case lb

    var id: String { rawValue }

    var displayName: String { rawValue }

    var kilogramsPerUnit: Double {
        switch self {
        case .kg: 1
        case .lb: 0.453_592_37
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    var restDurationSeconds: Int {
        didSet { UserDefaults.standard.set(restDurationSeconds, forKey: Keys.restDuration) }
    }

    var autoStartRestTimer: Bool {
        didSet { UserDefaults.standard.set(autoStartRestTimer, forKey: Keys.autoStart) }
    }

    var weightUnitRaw: String {
        didSet { UserDefaults.standard.set(weightUnitRaw, forKey: Keys.weightUnit) }
    }

    /// Bar weight for the plate calculator, in the display unit.
    var barWeight: Double {
        didSet { UserDefaults.standard.set(barWeight, forKey: Keys.barWeight) }
    }

    var healthSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(healthSyncEnabled, forKey: HealthService.enabledKey) }
    }

    /// Per-exercise progression step overrides, keyed by exercise UUID string,
    /// in the display unit. Missing key = the unit's standard barbell step.
    var progressionSteps: [String: Double] {
        didSet { UserDefaults.standard.set(progressionSteps, forKey: Keys.progressionSteps) }
    }

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
        set { weightUnitRaw = newValue.rawValue }
    }

    func progressionStep(for uuid: UUID?) -> Double {
        let fallback: Double = weightUnit == .lb ? 5 : 2.5
        guard let uuid else { return fallback }
        return progressionSteps[uuid.uuidString] ?? fallback
    }

    func setProgressionStep(_ value: Double, for uuid: UUID) {
        progressionSteps[uuid.uuidString] = value
    }

    private enum Keys {
        static let restDuration = "settings.restDurationSeconds"
        static let autoStart = "settings.autoStartRestTimer"
        static let weightUnit = "settings.weightUnit"
        static let barWeight = "settings.barWeight"
        static let progressionSteps = "settings.progressionSteps"
    }

    init() {
        let defaults = UserDefaults.standard
        let storedRest = defaults.integer(forKey: Keys.restDuration)
        restDurationSeconds = storedRest > 0 ? storedRest : 90
        autoStartRestTimer = defaults.object(forKey: Keys.autoStart) as? Bool ?? true
        let storedUnit = defaults.string(forKey: Keys.weightUnit) ?? WeightUnit.kg.rawValue
        weightUnitRaw = storedUnit
        if defaults.object(forKey: Keys.barWeight) != nil {
            barWeight = defaults.double(forKey: Keys.barWeight)
        } else {
            barWeight = storedUnit == WeightUnit.lb.rawValue ? 45 : 20
        }
        healthSyncEnabled = defaults.bool(forKey: HealthService.enabledKey)
        progressionSteps = defaults.dictionary(forKey: Keys.progressionSteps) as? [String: Double] ?? [:]
    }
}
