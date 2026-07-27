import Foundation
import SwiftData

extension GymSchemaV2 {
    @Model
    final class BodyWeightEntry {
        var date: Date = Date.now
        /// Stored canonically in kilograms; converted at the UI edge.
        var weightKg: Double = 0

        init(date: Date, weightKg: Double) {
            self.date = date
            self.weightKg = weightKg
        }
    }
}
