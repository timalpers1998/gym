import Foundation

enum MuscleGroup: String, CaseIterable, Codable, Identifiable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case cardio
    case other

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .chest: "figure.arms.open"
        case .back: "figure.climbing"
        case .legs: "figure.walk"
        case .shoulders: "figure.wave"
        case .arms: "figure.boxing"
        case .core: "figure.core.training"
        case .cardio: "heart.fill"
        case .other: "dumbbell.fill"
        }
    }
}

/// How an exercise is logged: reps × weight, or time under load.
enum ExerciseMeasurement: String, CaseIterable, Codable, Identifiable {
    case reps
    case duration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reps: "Reps & Weight"
        case .duration: "Duration"
        }
    }
}

enum SetType: String, CaseIterable, Codable, Identifiable {
    case working
    case dropSet = "dropset"
    case failure
    case amrap

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .working: "Working Set"
        case .dropSet: "Drop Set"
        case .failure: "To Failure"
        case .amrap: "AMRAP"
        }
    }

    /// Single-letter badge shown in place of the set number; nil for plain
    /// working sets, which keep their running number.
    var marker: String? {
        switch self {
        case .working: nil
        case .dropSet: "D"
        case .failure: "F"
        case .amrap: "A"
        }
    }
}

enum Equipment: String, CaseIterable, Codable, Identifiable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case band
    case other

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}
