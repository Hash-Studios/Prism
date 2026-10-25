import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct PrismAiGenerationAttributes: ActivityAttributes {
  enum Phase: String, Codable, Hashable, Sendable {
    case generating
    case ready
    case failed
  }

  struct ContentState: Codable, Hashable, Sendable {
    var phase: Phase
    var startedAt: Date
    var thumbnail: String?
    var detail: String?
  }

  struct Copy: Codable, Hashable, Sendable {
    var generating: String
    var ready: String
    var failed: String
    var stale: String
    var open: String
  }

  static let expectedSeconds: TimeInterval = 20

  var prompt: String
  var style: String
  var accentARGB: Int
  var swatchARGB: [Int]
  var copy: Copy
}

enum PrismLiveActivityFiles {
  static let appGroup = "group.com.hash.prism"

  static var directory: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appendingPathComponent("LiveActivities", isDirectory: true)
  }

  static func url(named name: String) -> URL? {
    directory?.appendingPathComponent(name, isDirectory: false)
  }
}
