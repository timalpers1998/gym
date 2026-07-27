import SwiftUI
import SwiftData

struct SetRowView: View {
    let set: SetEntry

    @Environment(RestTimerModel.self) private var restTimer
    @Environment(AppSettings.self) private var settings

    @State private var repsText = ""
    @State private var weightText = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case weight, reps
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(set.isWarmup ? "W" : "\(set.orderIndex + 1)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(set.isWarmup ? Color.orange : Color.secondary)
                .frame(width: 24)

            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 76)
            Text(settings.weightUnit.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)
            Text("reps")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                toggleCompleted()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.08) : Color.clear)
        .contextMenu {
            Button {
                set.isWarmup.toggle()
            } label: {
                Label(
                    set.isWarmup ? "Mark as Working Set" : "Mark as Warm-up",
                    systemImage: "flame"
                )
            }
        }
        .onAppear {
            weightText = set.weight > 0 ? Format.editableWeight(set.weight) : ""
            repsText = set.reps > 0 ? "\(set.reps)" : ""
        }
        .onChange(of: weightText) { _, newValue in
            set.weight = Format.parseWeight(newValue)
        }
        .onChange(of: repsText) { _, newValue in
            set.reps = Int(newValue) ?? 0
        }
    }

    private func toggleCompleted() {
        if set.isCompleted {
            set.isCompleted = false
            set.completedAt = nil
        } else {
            set.isCompleted = true
            set.completedAt = Date.now
            focusedField = nil
            if settings.autoStartRestTimer && !set.isWarmup {
                restTimer.start()
            }
        }
    }
}
