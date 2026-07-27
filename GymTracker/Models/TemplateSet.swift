import Foundation
import SwiftData

extension GymSchemaV1 {
    @Model
    final class TemplateSet {
        var orderIndex: Int = 0
        var targetReps: Int = 10
        var targetWeight: Double = 0
        var templateExercise: TemplateExercise? = nil

        init(orderIndex: Int, targetReps: Int = 10, targetWeight: Double = 0) {
            self.orderIndex = orderIndex
            self.targetReps = targetReps
            self.targetWeight = targetWeight
        }
    }
}
