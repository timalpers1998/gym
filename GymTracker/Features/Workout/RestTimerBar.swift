import SwiftUI

struct RestTimerBar: View {
    @Environment(RestTimerModel.self) private var restTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .foregroundStyle(.tint)

                Text(Format.timerCountdown(seconds: restTimer.remainingSeconds(at: timeline.date)))
                    .font(.title3.monospacedDigit().bold())
                    .frame(minWidth: 64, alignment: .leading)

                ProgressView(value: restTimer.progress(at: timeline.date))

                Button("+15s") {
                    restTimer.add(seconds: 15)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Skip") {
                    restTimer.skip()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .task(id: restTimer.endDate) {
            // Clear the timer state when the countdown runs out naturally.
            guard let end = restTimer.endDate else { return }
            let interval = end.timeIntervalSinceNow
            if interval > 0 {
                try? await Task.sleep(for: .seconds(interval))
            }
            if !Task.isCancelled && restTimer.endDate == end {
                restTimer.finish()
            }
        }
    }
}
