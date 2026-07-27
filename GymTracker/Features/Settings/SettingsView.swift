import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate)
    private var finishedWorkouts: [Workout]

    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var exportURL: URL?
    @State private var backupURL: URL?
    @State private var showingRestoreConfirmation = false
    @State private var showingRestoreImporter = false
    @State private var restoreResult: String?

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
                    Toggle("Sync workouts to Apple Health", isOn: $settings.healthSyncEnabled)
                        .disabled(!HealthService.isAvailable)
                        .onChange(of: settings.healthSyncEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    let granted = await HealthService.requestAuthorization()
                                    if !granted {
                                        settings.healthSyncEnabled = false
                                    }
                                }
                            }
                        }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Finished workouts are saved as strength training and body weight entries as weight samples. Manage access in the Health app. Deleting a workout here does not remove it from Health.")
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
                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Back Up All Data", systemImage: "arrow.down.doc")
                        }
                    } else {
                        Label("Back Up All Data", systemImage: "arrow.down.doc")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        showingRestoreConfirmation = true
                    } label: {
                        Label("Restore from Backup", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("The CSV export covers every set from \(finishedWorkouts.count) workout\(finishedWorkouts.count == 1 ? "" : "s"). The backup file also includes routines, body weight, effort logs and settings — save it to Files or iCloud Drive, and restore it on a new phone to move everything over.")
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
                backupURL = try? BackupService.export(context: modelContext, settings: settings)
            }
            .confirmationDialog(
                "Restore from Backup",
                isPresented: $showingRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("Choose Backup File") {
                    showingRestoreImporter = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The backup is merged into this device's data. Nothing is deleted, and entries that already exist here are skipped.")
            }
            .fileImporter(
                isPresented: $showingRestoreImporter,
                allowedContentTypes: [.json]
            ) { result in
                restoreResult = restore(result)
            }
            .alert(
                "Restore",
                isPresented: Binding(
                    get: { restoreResult != nil },
                    set: { if !$0 { restoreResult = nil } }
                ),
                presenting: restoreResult
            ) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
        }
    }

    private func restore(_ result: Result<URL, any Error>) -> String {
        do {
            let summary = try BackupService.importBackup(
                from: try result.get(),
                context: modelContext,
                settings: settings
            )
            WidgetDataStore.refresh(context: modelContext)
            // The finishedWorkouts query only refreshes on the next view
            // update, so fetch directly to include what was just imported.
            let finished = (try? modelContext.fetch(FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.endDate != nil },
                sortBy: [SortDescriptor(\.startDate)]
            ))) ?? []
            exportURL = try? CSVExporter.export(workouts: finished)
            backupURL = try? BackupService.export(context: modelContext, settings: settings)

            var parts: [String] = []
            func append(_ count: Int, _ singular: String, _ plural: String? = nil) {
                guard count > 0 else { return }
                parts.append("\(count) \(count == 1 ? singular : plural ?? singular + "s")")
            }
            append(summary.workoutsAdded, "workout")
            append(summary.templatesAdded, "routine")
            append(summary.exercisesAdded, "exercise")
            append(summary.bodyWeightAdded, "body weight entry", "body weight entries")
            append(summary.effortsAdded, "effort log")

            var message = parts.isEmpty
                ? "Everything in the backup is already on this device."
                : "Added \(parts.joined(separator: ", "))."
            if summary.skipped > 0 && !parts.isEmpty {
                message += " Skipped \(summary.skipped) already present."
            }
            if summary.settingsApplied {
                message += " Settings restored."
            }
            return message
        } catch {
            return "Restore failed: \(error.localizedDescription)"
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
