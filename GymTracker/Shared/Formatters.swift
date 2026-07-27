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
}
