import Foundation
import HealthKit

/// Write-only Apple Health integration: finished workouts as strength
/// training, body-weight entries as bodyMass samples.
@MainActor
enum HealthService {
    static let enabledKey = "settings.healthSyncEnabled"

    private static let store = HKHealthStore()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    static var isEnabled: Bool {
        isAvailable && UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Returns false when the authorization request itself failed (the user
    /// declining individual types does not throw — iOS handles that later).
    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let shareTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.bodyMass),
        ]
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: [])
            return true
        } catch {
            return false
        }
    }

    static func saveWorkout(start: Date, end: Date) async {
        guard isEnabled, end > start else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            // A nil workout with no thrown error still means the save
            // succeeded (e.g. device locked), so the result is ignored.
            _ = try await builder.finishWorkout()
        } catch {
            print("Health workout save failed: \(error)")
        }
    }

    static func saveBodyWeight(kilograms: Double, date: Date) async {
        guard isEnabled, kilograms > 0 else { return }
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms),
            start: date,
            end: date
        )
        try? await store.save(sample)
    }
}
