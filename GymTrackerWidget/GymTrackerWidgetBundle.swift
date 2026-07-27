import WidgetKit
import SwiftUI

@main
struct GymTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        RestTimerLiveActivity()
    }
}
