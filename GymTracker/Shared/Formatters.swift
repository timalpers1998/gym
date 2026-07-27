import Foundation

enum Format {
    static func duration(seconds: Int) -> String {
        if seconds >= 3600 {
            return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
        }
        return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    static func timerCountdown(seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    static func weight(_ value: Double, unit: WeightUnit) -> String {
        "\(plainWeight(value)) \(unit.displayName)"
    }

    static func plainWeight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    /// Locale-neutral representation for pre-filling editable text fields.
    static func editableWeight(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 100_000 {
            return String(Int(value))
        }
        return String(value)
    }

    static func parseWeight(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Editable representation of a set duration: "45" stays seconds-only
    /// under a minute, longer runs show "1:30".
    static func editableDuration(_ seconds: Int) -> String {
        guard seconds >= 60 else { return String(seconds) }
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    /// Parses "90" (seconds) or "1:30" (minutes:seconds) from a set field.
    static func parseDuration(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":")
        if parts.count == 2, let minutes = Int(parts[0]), let seconds = Int(parts[1]) {
            return max(0, minutes * 60 + seconds)
        }
        return max(0, Int(trimmed) ?? 0)
    }
}
