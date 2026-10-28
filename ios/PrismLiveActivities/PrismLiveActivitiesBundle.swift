import SwiftUI
import WidgetKit

@main
struct PrismLiveActivitiesBundle: WidgetBundle {
  var body: some Widget {
    AiGenerationLiveActivity()
    ReviewQueueLiveActivity()
    PrismWotdWidget()
    PrismStreakWidget()
  }
}
