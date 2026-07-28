import Foundation
import SwiftData

/// V5 adds body measurements and progress photos. V4's model classes are
/// reused unchanged (same pattern as V2/V3 side entities), so V4 → V5 is a
/// lightweight migration that only creates two new tables.
enum GymSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        GymSchemaV4.models + [BodyMeasurement.self, ProgressPhoto.self]
    }
}

extension GymSchemaV5 {
    @Model
    final class BodyMeasurement {
        var date: Date = Date.now
        var metricRaw: String = BodyMetric.waist.rawValue
        /// Stored canonically in centimeters; converted at the UI edge.
        var valueCm: Double = 0

        var metric: BodyMetric {
            get { BodyMetric(rawValue: metricRaw) ?? .waist }
            set { metricRaw = newValue.rawValue }
        }

        init(date: Date, metric: BodyMetric, valueCm: Double) {
            self.date = date
            self.metricRaw = metric.rawValue
            self.valueCm = valueCm
        }
    }

    /// Metadata row for a photo stored on disk by PhotoStore — the image
    /// itself never enters the database (or the JSON backup).
    @Model
    final class ProgressPhoto {
        var date: Date = Date.now
        var fileName: String = ""
        var notes: String = ""

        init(date: Date, fileName: String, notes: String = "") {
            self.date = date
            self.fileName = fileName
            self.notes = notes
        }
    }
}
