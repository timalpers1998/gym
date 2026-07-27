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
