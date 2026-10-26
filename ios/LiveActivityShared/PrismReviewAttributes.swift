import ActivityKit
import Foundation

/// The admin review queue. The server starts, updates and ends it through FCM, so the property names here are the
/// `content-state` keys that functions/src/reviewLiveActivity.ts sends.
@available(iOS 16.1, *)
struct PrismReviewAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable, Sendable {
    var pending: Int
    var newestBy: String?
    var oldestAt: Double?
  }
}
