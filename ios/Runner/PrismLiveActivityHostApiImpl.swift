import ActivityKit
import ImageIO
import UIKit
import UniformTypeIdentifiers

@MainActor
final class PrismLiveActivityHostApiImpl: @preconcurrency PrismLiveActivityHostApi {
  private var backgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]

  func startAiGeneration(request: AiActivityRequest) throws -> String? {
    guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
    for activity in Activity<PrismAiGenerationAttributes>.activities {
      let id = activity.id
      Task { await Self.end(id, content: nil, dismissalPolicy: .immediate) }
    }
    let attributes = PrismAiGenerationAttributes(
      prompt: request.prompt,
      style: request.style,
      accentARGB: Int(request.accentArgb),
      swatchARGB: request.swatchArgb.map { Int($0) },
      copy: .init(
        generating: request.generatingTitle,
        ready: request.readyTitle,
        failed: request.failedTitle,
        stale: request.staleTitle,
        open: request.openLabel
      )
    )
    let now = Date()
    let state = PrismAiGenerationAttributes.ContentState(phase: .generating, startedAt: now)
    guard let activity = try? Activity.request(
      attributes: attributes,
      content: .init(state: state, staleDate: now.addingTimeInterval(90))
    ) else { return nil }
    let id = activity.id
    backgroundTasks[id] = UIApplication.shared.beginBackgroundTask(withName: "prism.ai-generation") { [weak self] in
      MainActor.assumeIsolated { self?.endBackgroundTask(id) }
    }
    return id
  }

  func finishAiGeneration(activityId: String, imageUrl: String, completion: @escaping (Result<Void, Error>) -> Void) {
    guard #available(iOS 16.2, *), let activity = Self.activity(activityId) else {
      endBackgroundTask(activityId)
      completion(.success(()))
      return
    }
    Task {
      var state = activity.content.state
      state.phase = .ready
      state.thumbnail = await Self.saveThumbnail(from: URL(string: imageUrl), named: "ai-\(activityId).jpg")
      await settle(activityId, state: state, linger: 15 * 60)
      completion(.success(()))
    }
  }

  func failAiGeneration(activityId: String, detail: String) throws {
    guard #available(iOS 16.2, *), let activity = Self.activity(activityId) else {
      endBackgroundTask(activityId)
      return
    }
    var state = activity.content.state
    state.phase = .failed
    state.detail = detail
    Task { await settle(activityId, state: state, linger: 5 * 60) }
  }

  func cancelAiGeneration(activityId: String) throws {
    guard #available(iOS 16.2, *) else { return }
    Task {
      await Self.end(activityId, content: nil, dismissalPolicy: .immediate)
      endBackgroundTask(activityId)
    }
  }

  /// In the foreground the app shows the result itself. In the background the Dynamic Island shows it for a moment,
  /// then the Lock Screen keeps it for [linger] seconds.
  @available(iOS 16.2, *)
  private func settle(_ id: String, state: PrismAiGenerationAttributes.ContentState, linger: TimeInterval) async {
    let content = ActivityContent(state: state, staleDate: nil)
    if UIApplication.shared.applicationState == .active {
      await Self.end(id, content: content, dismissalPolicy: .immediate)
    } else {
      await Self.update(id, content: content)
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      await Self.end(id, content: content, dismissalPolicy: .after(Date().addingTimeInterval(linger)))
    }
    endBackgroundTask(id)
  }

  @available(iOS 16.2, *)
  private nonisolated static func update(_ id: String, content: ActivityContent<PrismAiGenerationAttributes.ContentState>) async {
    await activity(id)?.update(content)
  }

  @available(iOS 16.2, *)
  private nonisolated static func end(
    _ id: String,
    content: ActivityContent<PrismAiGenerationAttributes.ContentState>?,
    dismissalPolicy: ActivityUIDismissalPolicy
  ) async {
    await activity(id)?.end(content, dismissalPolicy: dismissalPolicy)
  }

  private func endBackgroundTask(_ id: String) {
    guard let task = backgroundTasks.removeValue(forKey: id) else { return }
    UIApplication.shared.endBackgroundTask(task)
  }

  @available(iOS 16.2, *)
  private nonisolated static func activity(_ id: String) -> Activity<PrismAiGenerationAttributes>? {
    Activity<PrismAiGenerationAttributes>.activities.first { $0.id == id }
  }

  /// Live Activities cannot load from the network, so the app writes a small copy to the shared App Group container.
  private static func saveThumbnail(from url: URL?, named name: String) async -> String? {
    guard let url, let directory = PrismLiveActivityFiles.directory,
          let target = PrismLiveActivityFiles.url(named: name),
          let (data, _) = try? await URLSession.shared.data(from: url),
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 360,
          ] as CFDictionary)
    else { return nil }
    let fileManager = FileManager.default
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    for old in (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
      try? fileManager.removeItem(at: old)
    }
    guard let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? name : nil
  }
}
