import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings

    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate)
    private var finishedWorkouts: [Workout]

    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var exportURL: URL?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Rest Timer") {
                    Stepper(value: $settings.restDurationSeconds, in: 15...600, step: 15) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(Format.duration(seconds: settings.restDurationSeconds))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Toggle("Auto-start after completing a set", isOn: $settings.autoStartRestTimer)
                    notificationRow
                }

                Section {
                    Picker("Weight unit", selection: $settings.weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Changing the unit only changes the label — logged weights are not converted.")
                }

                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export Workout History", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label("Export Workout History", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Exports every set from \(finishedWorkouts.count) workout\(finishedWorkouts.count == 1 ? "" : "s") as a CSV file.")
                }

                Section {
                    LabeledContent(
                        "Version",
                        value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
                    )
                } footer: {
                    Text("All data is stored on this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                notificationStatus = await UNUserNotificationCenter.current()
                    .notificationSettings().authorizationStatus
                exportURL = try? CSVExporter.export(workouts: finishedWorkouts)
            }
        }
    }

    @ViewBuilder
    private var notificationRow: some View {
        switch notificationStatus {
        case .denied:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                HStack {
                    Text("Notifications are off")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Enable in Settings")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        case .authorized, .provisional, .ephemeral:
            LabeledContent("Notifications", value: "On")
        default:
            LabeledContent("Notifications", value: "Asked when the timer first runs")
        }
    }
}
