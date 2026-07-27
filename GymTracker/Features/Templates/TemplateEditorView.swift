import SwiftUI
import SwiftData

/// Edits a routine live in the model context. When creating a new routine the
/// template is inserted on appear and deleted again on Cancel.
struct TemplateEditorView: View {
    private let existingTemplate: WorkoutTemplate?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var template: WorkoutTemplate?
    @State private var name: String
    @State private var showingExercisePicker = false

    private var isNew: Bool { existingTemplate == nil }

    init(template: WorkoutTemplate?) {
        self.existingTemplate = template
        _template = State(initialValue: template)
        _name = State(initialValue: template?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("Routine name (e.g. Push Day)", text: $name)
                }

                Section {
                    if let template {
                        ForEach(template.orderedExercises) { templateExercise in
                            NavigationLink {
                                TemplateSetSchemeEditor(templateExercise: templateExercise)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(templateExercise.exerciseName)
                                        if let group = templateExercise.supersetGroup,
                                           let label = template.supersetLabel(for: group) {
                                            Text(label)
                                                .font(.caption2.bold())
                                                .foregroundStyle(.teal)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.teal.opacity(0.15), in: Capsule())
                                        }
                                    }
                                    Text(setSummary(for: templateExercise))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contextMenu {
                                Button {
                                    WorkoutFactory.supersetWithNext(templateExercise, context: context)
                                } label: {
                                    Label("Superset with Next", systemImage: "link")
                                }
                                .disabled(template.orderedExercises.last === templateExercise)
                                if templateExercise.supersetGroup != nil {
                                    Button {
                                        WorkoutFactory.removeFromSuperset(templateExercise, context: context)
                                    } label: {
                                        Label("Remove from Superset", systemImage: "scissors")
                                    }
                                }
                            }
                        }
                        .onMove { source, destination in
                            moveExercises(from: source, to: destination)
                        }
                        .onDelete { offsets in
                            deleteExercises(at: offsets)
                        }
                    }

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        EditButton()
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isNew ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Existing routines are edited live, so there is no revert —
                // offer a single "Done" instead of a misleading Cancel.
                if isNew {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            cancel()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isNew ? "Save" : "Done") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercises in
                    addExercises(exercises)
                }
            }
            .onAppear {
                if template == nil {
                    let created = WorkoutTemplate(name: "")
                    context.insert(created)
                    template = created
                }
            }
        }
        .interactiveDismissDisabled(isNew)
    }

    private func setSummary(for templateExercise: TemplateExercise) -> String {
        let sets = templateExercise.orderedSets
        guard !sets.isEmpty else { return "No sets" }
        if templateExercise.exercise?.measurement == .duration {
            let times = sets.map { Format.duration(seconds: $0.targetDurationSeconds) }.joined(separator: "/")
            return "\(sets.count) sets · \(times)"
        }
        let reps = sets.map { "\($0.targetReps)" }.joined(separator: "/")
        return "\(sets.count) sets · \(reps) reps"
    }

    private func addExercises(_ exercises: [Exercise]) {
        guard let template else { return }
        var nextIndex = (template.orderedExercises.map(\.orderIndex).max() ?? -1) + 1
        for exercise in exercises {
            let templateExercise = TemplateExercise(orderIndex: nextIndex, exercise: exercise)
            templateExercise.template = template
            context.insert(templateExercise)
            for setIndex in 0..<3 {
                let set = TemplateSet(orderIndex: setIndex)
                set.templateExercise = templateExercise
                context.insert(set)
            }
            nextIndex += 1
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        guard let template else { return }
        var ordered = template.orderedExercises
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.orderIndex = index
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        guard let template else { return }
        let ordered = template.orderedExercises
        for index in offsets {
            context.delete(ordered[index])
        }
        let remaining = ordered.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        for (index, item) in remaining.enumerated() {
            item.orderIndex = index
        }
    }

    private func save() {
        guard let template else { return }
        template.name = name.trimmingCharacters(in: .whitespaces)
        try? context.save()
        dismiss()
    }

    private func cancel() {
        if isNew, let template {
            context.delete(template)
        }
        try? context.save()
        dismiss()
    }
}
