import Foundation

/// A recommended next target for a set.
struct ProgressionSuggestion {
    let weight: Double
    let reps: Int
    let estTenRM: Double
}

/// Proposes the next set target as the smallest increase in estimated 10RM
/// over the previous session's performance.
enum ProgressionCalculator {
    /// Guards against floating-point noise counting as "an increase".
    private static let epsilon = 0.05

    /// Weight the lifter could move for 10 reps, derived from the Epley 1RM.
    static func estimatedTenRepMax(weight: Double, reps: Int) -> Double {
        ProgressCalculator.epleyOneRepMax(weight: weight, reps: reps) / (1 + 10.0 / 30.0)
    }

    /// Candidates keep reps at or above last session's — dropping reps while
    /// adding load can game the 10RM estimate into arbitrarily small
    /// "increases" that are really harder sets.
    static func nextProgression(
        lastWeight: Double,
        lastReps: Int,
        increment: Double,
        allowIncrease: Bool
    ) -> ProgressionSuggestion? {
        guard lastReps > 0 else { return nil }

        if lastWeight <= 0 {
            // Bodyweight movement: progress by a rep.
            let reps = allowIncrease ? lastReps + 1 : lastReps
            return ProgressionSuggestion(weight: 0, reps: reps, estTenRM: 0)
        }

        let baseline = estimatedTenRepMax(weight: lastWeight, reps: lastReps)
        guard allowIncrease else {
            return ProgressionSuggestion(weight: lastWeight, reps: lastReps, estTenRM: baseline)
        }
        guard increment > 0 else { return nil }

        let repUpperBound = max(lastReps, min(30, lastReps + 2))
        var best: ProgressionSuggestion?
        for step in 0...4 {
            let weight = lastWeight + Double(step) * increment
            for reps in lastReps...repUpperBound {
                let tenRM = estimatedTenRepMax(weight: weight, reps: reps)
                guard tenRM > baseline + epsilon else { continue }
                if let current = best {
                    // Ties prefer the lighter load, i.e. rep progression.
                    if tenRM < current.estTenRM - 0.001
                        || (abs(tenRM - current.estTenRM) <= 0.001 && weight < current.weight) {
                        best = ProgressionSuggestion(weight: weight, reps: reps, estTenRM: tenRM)
                    }
                } else {
                    best = ProgressionSuggestion(weight: weight, reps: reps, estTenRM: tenRM)
                }
            }
        }
        return best
    }
}
