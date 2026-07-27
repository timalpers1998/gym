import Foundation
import Observation

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg
    case lb

    var id: String { rawValue }

    var displayName: String { rawValue }
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

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
        set { weightUnitRaw = newValue.rawValue }
    }

    private enum Keys {
        static let restDuration = "settings.restDurationSeconds"
        static let autoStart = "settings.autoStartRestTimer"
        static let weightUnit = "settings.weightUnit"
    }

    init() {
        let defaults = UserDefaults.standard
        let storedRest = defaults.integer(forKey: Keys.restDuration)
        restDurationSeconds = storedRest > 0 ? storedRest : 90
        autoStartRestTimer = defaults.object(forKey: Keys.autoStart) as? Bool ?? true
        weightUnitRaw = defaults.string(forKey: Keys.weightUnit) ?? WeightUnit.kg.rawValue
    }
}
