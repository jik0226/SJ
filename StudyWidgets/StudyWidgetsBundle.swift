// StudyWidgetsBundle — the @main entry point for the widget extension.
// Hosts the home-screen widgets and the live activity together.

import WidgetKit
import SwiftUI

@main
struct StudyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DDayWidget()
        TodayStudyTimeWidget()
        PlantWidget()
        TimerLiveActivity()
    }
}
