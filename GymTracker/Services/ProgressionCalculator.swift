import Foundation

/// A recommended next target for a set.
struct ProgressionSuggestion {
    let weight: Double
    let reps: Int
    let estTenRM: Double
}

/// Proposes the next set target as the smallest increase in estimated 10RM
/// over the previous session's performance, following a double-progression
/// scheme: reps climb toward a cap, weight-up moves (optionally shedding one
/// rep) take over when they're the gentler step, and hitting the cap forces
/// a weight increase with reps re-entering at a near-equal 10RM.
enum ProgressionCalculator {
    /// At this many reps the next suggestion always adds weight.
    private static let repCap = 12
    /// Weight-up/rep-down moves never suggest fewer reps than this.
    private static let repFloor = 6
    /// A rep-down candidate must be at most this fraction of the best
    /// rep-holding candidate's 10RM increase — meaningfully gentler,
    /// not marginally.
    private static let dropAdvantage = 0.6
    /// A cap reset may re-enter up to this far below the old 10RM,
    /// absorbing exact-tie coincidences in the Epley grid.
    private static let resetTolerance = 0.5
    /// Guards against floating-point noise counting as "an increase".
    private static let epsilon = 0.05

    /// Weight the lifter could move for 10 reps, derived from the Epley 1RM.
    static func estimatedTenRepMax(weight: Double, reps: Int) -> Double {
        ProgressCalculator.epleyOneRepMax(weight: weight, reps: reps) / (1 + 10.0 / 30.0)
    }

    static func nextProgression(
        lastWeight: Double,
        lastReps: Int,
        increment: Double,
        allowIncrease: Bool
    ) -> ProgressionSuggestion? {
        guard lastReps > 0 else { return nil }

        if lastWeight <= 0 {
            // Bodyweight movement: progress by a rep, no cap.
            let reps = allowIncrease ? lastReps + 1 : lastReps
            return ProgressionSuggestion(weight: 0, reps: reps, estTenRM: 0)
        }

        let baseline = estimatedTenRepMax(weight: lastWeight, reps: lastReps)
        guard allowIncrease else {
            return ProgressionSuggestion(weight: lastWeight, reps: lastReps, estTenRM: baseline)
        }
        guard increment > 0 else { return nil }

        if lastReps >= repCap {
            return capReset(lastWeight: lastWeight, baseline: baseline, increment: increment)
        }

        func suggestion(_ weight: Double, _ reps: Int) -> ProgressionSuggestion {
            ProgressionSuggestion(
                weight: weight,
                reps: reps,
                estTenRM: estimatedTenRepMax(weight: weight, reps: reps)
            )
        }

        // The two rep-holding moves; the gentler wins, ties prefer the
        // lighter load (rep progression).
        var holds = [suggestion(lastWeight + increment, lastReps)]
        if lastReps + 1 <= repCap {
            holds.append(suggestion(lastWeight, lastReps + 1))
        }
        let bestHold = holds
            .filter { $0.estTenRM > baseline + epsilon }
            .min { lhs, rhs in
                if abs(lhs.estTenRM - rhs.estTenRM) <= 0.001 { return lhs.weight < rhs.weight }
                return lhs.estTenRM < rhs.estTenRM
            }

        // The weight-up/rep-down move, taken only when meaningfully gentler.
        if lastReps - 1 >= repFloor {
            let drop = suggestion(lastWeight + increment, lastReps - 1)
            if drop.estTenRM > baseline + epsilon {
                if let bestHold {
                    if drop.estTenRM - baseline <= dropAdvantage * (bestHold.estTenRM - baseline) {
                        return drop
                    }
                } else {
                    return drop
                }
            }
        }
        return bestHold
    }

    /// At the rep cap, weight must rise; reps re-enter at the lowest count
    /// whose 10RM lands at or just below the old one.
    private static func capReset(
        lastWeight: Double,
        baseline: Double,
        increment: Double
    ) -> ProgressionSuggestion {
        let weight = lastWeight + increment
        for reps in repFloor...repCap {
            let tenRM = estimatedTenRepMax(weight: weight, reps: reps)
            if tenRM >= baseline - resetTolerance {
                return ProgressionSuggestion(weight: weight, reps: reps, estTenRM: tenRM)
            }
        }
        return ProgressionSuggestion(
            weight: weight,
            reps: repCap,
            estTenRM: estimatedTenRepMax(weight: weight, reps: repCap)
        )
    }
}
