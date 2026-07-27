import Foundation
import SwiftData

extension GymSchemaV3 {
    /// Reps-in-reserve recorded for a completed set. Kept as a standalone
    /// entity keyed by (workout start, exercise, set index) — a relationship
    /// to the frozen SetEntry would mutate V1's checksum.
    @Model
    final class SetEffort {
        var workoutStartDate: Date = Date.distantPast
        var exerciseUUID: UUID? = nil
        var setOrderIndex: Int = 0
        /// 0 = nothing left in the tank, 4 = four or more reps in reserve.
        var rir: Int = 0

        init(workoutStartDate: Date, exerciseUUID: UUID?, setOrderIndex: Int, rir: Int) {
            self.workoutStartDate = workoutStartDate
            self.exerciseUUID = exerciseUUID
            self.setOrderIndex = setOrderIndex
            self.rir = rir
        }
    }
}
