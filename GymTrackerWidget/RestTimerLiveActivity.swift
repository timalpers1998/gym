import ActivityKit
import WidgetKit
import SwiftUI

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            RestTimerLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.isStale {
                        Text("Done")
                            .font(.title3.bold())
                    } else {
                        Text(timerInterval: timerRange(context.state), countsDown: true)
                            .font(.title3.monospacedDigit().bold())
                            .frame(width: 72)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.isStale {
                        ProgressView(timerInterval: timerRange(context.state), countsDown: true)
                            .tint(.orange)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                if context.isStale {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                } else {
                    Text(timerInterval: timerRange(context.state), countsDown: true)
                        .monospacedDigit()
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.orange)
                }
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct RestTimerLockScreenView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Rest Timer", systemImage: "timer")
                    .font(.headline)
                Spacer()
                if context.isStale {
                    Text("Done — next set!")
                        .font(.headline.bold())
                } else {
                    Text(timerInterval: timerRange(context.state), countsDown: true)
                        .font(.title2.monospacedDigit().bold())
                        .frame(maxWidth: 96)
                        .multilineTextAlignment(.trailing)
                }
            }
            if !context.isStale {
                ProgressView(timerInterval: timerRange(context.state), countsDown: true)
                    .tint(.orange)
            }
        }
        .padding(16)
    }
}

/// Guard against an inverted range — a ClosedRange with lower > upper traps.
private func timerRange(_ state: RestTimerAttributes.ContentState) -> ClosedRange<Date> {
    min(state.startDate, state.endDate)...state.endDate
}
