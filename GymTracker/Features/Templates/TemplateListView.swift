import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \WorkoutTemplate.name)
    private var templates: [WorkoutTemplate]

    @State private var editingTemplate: WorkoutTemplate?
    @State private var showingNewTemplate = false

    var body: some View {
        List {
            ForEach(templates) { template in
                Button {
                    editingTemplate = template
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .foregroundStyle(.primary)
                        Text(summary(for: template))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(templates[index])
                }
                try? context.save()
            }
        }
        .navigationTitle("Routines")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewTemplate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(template: template)
        }
        .sheet(isPresented: $showingNewTemplate) {
            TemplateEditorView(template: nil)
        }
        .overlay {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No Routines",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Create a routine like Push, Pull, or Legs to start workouts with one tap.")
                )
            }
        }
    }

    private func summary(for template: WorkoutTemplate) -> String {
        let count = template.orderedExercises.count
        let lastUsed = template.lastUsedAt.map { " · last used \($0.formatted(.dateTime.day().month()))" } ?? ""
        return "\(count) exercise\(count == 1 ? "" : "s")\(lastUsed)"
    }
}
