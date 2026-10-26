import ActivityKit
import ImageIO
import UIKit
import UniformTypeIdentifiers

@MainActor
final class PrismLiveActivityHostApiImpl: @preconcurrency PrismLiveActivityHostApi {
  private var backgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]
  private var workTasks: [String: Task<Void, Never>] = [:]
  private var workIDs: [String: UUID] = [:]

  init() {
    Self.removeExpiredThumbnails()
    if #available(iOS 16.2, *) {
      for activity in Activity<PrismAiGenerationAttributes>.activities where activity.content.state.phase == .generating {
        let id = activity.id
        Task {
          await Self.end(id, content: nil, dismissalPolicy: .immediate)
          Self.removeThumbnail(named: Self.thumbnailName(for: id))
        }
      }
    }
  }

  func startAiGeneration(request: AiActivityRequest) throws -> String? {
    guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
    Self.removeExpiredThumbnails()
    for activity in Activity<PrismAiGenerationAttributes>.activities {
      let id = activity.id
      workIDs.removeValue(forKey: id)
      workTasks.removeValue(forKey: id)?.cancel()
      endBackgroundTask(id)
      Task {
        await Self.end(id, content: nil, dismissalPolicy: .immediate)
        Self.removeThumbnail(named: Self.thumbnailName(for: id))
      }
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
      MainActor.assumeIsolated {
        self?.workIDs.removeValue(forKey: id)
        self?.workTasks.removeValue(forKey: id)?.cancel()
        self?.endBackgroundTask(id)
        Task {
          await Self.end(id, content: nil, dismissalPolicy: .immediate)
          Self.removeThumbnail(named: Self.thumbnailName(for: id))
        }
      }
    }
    return id
  }

  func finishAiGeneration(activityId: String, imageUrl: String, completion: @escaping (Result<Void, Error>) -> Void) {
    guard #available(iOS 16.2, *), let activity = Self.activity(activityId) else {
      workIDs.removeValue(forKey: activityId)
      workTasks.removeValue(forKey: activityId)?.cancel()
      endBackgroundTask(activityId)
      completion(.success(()))
      return
    }
    workIDs.removeValue(forKey: activityId)
    workTasks.removeValue(forKey: activityId)?.cancel()
    let workID = UUID()
    workIDs[activityId] = workID
    workTasks[activityId] = Task {
      defer {
        if workIDs[activityId] == workID {
          workIDs.removeValue(forKey: activityId)
          workTasks.removeValue(forKey: activityId)
          endBackgroundTask(activityId)
        }
      }
      var state = activity.content.state
      state.phase = .ready
      state.thumbnail = await Self.saveThumbnail(from: URL(string: imageUrl), named: Self.thumbnailName(for: activityId))
      guard !Task.isCancelled, workIDs[activityId] == workID, Self.activity(activityId) != nil else {
        completion(.success(()))
        return
      }
      await settle(activityId, state: state, linger: 15 * 60)
      completion(.success(()))
    }
  }

  func failAiGeneration(activityId: String, detail: String) throws {
    guard #available(iOS 16.2, *), let activity = Self.activity(activityId) else {
      workIDs.removeValue(forKey: activityId)
      workTasks.removeValue(forKey: activityId)?.cancel()
      endBackgroundTask(activityId)
      return
    }
    var state = activity.content.state
    state.phase = .failed
    state.detail = detail
    Self.removeThumbnail(named: Self.thumbnailName(for: activityId))
    workIDs.removeValue(forKey: activityId)
    workTasks.removeValue(forKey: activityId)?.cancel()
    let workID = UUID()
    workIDs[activityId] = workID
    workTasks[activityId] = Task {
      defer {
        if workIDs[activityId] == workID {
          workIDs.removeValue(forKey: activityId)
          workTasks.removeValue(forKey: activityId)
          endBackgroundTask(activityId)
        }
      }
      await settle(activityId, state: state, linger: 5 * 60)
    }
  }

  func cancelAiGeneration(activityId: String) throws {
    guard #available(iOS 16.2, *) else { return }
    Task {
      workTasks.removeValue(forKey: activityId)?.cancel()
      workIDs.removeValue(forKey: activityId)
      await Self.end(activityId, content: nil, dismissalPolicy: .immediate)
      endBackgroundTask(activityId)
      Self.removeThumbnail(named: Self.thumbnailName(for: activityId))
    }
  }

  /// In the foreground the app shows the result itself. In the background the Dynamic Island shows it for a moment,
  /// then the Lock Screen keeps it for [linger] seconds.
  @available(iOS 16.2, *)
  private func settle(_ id: String, state: PrismAiGenerationAttributes.ContentState, linger: TimeInterval) async {
    let content = ActivityContent(state: state, staleDate: nil)
    if UIApplication.shared.applicationState == .active {
      await Self.end(id, content: content, dismissalPolicy: .immediate)
      if let name = state.thumbnail { Self.removeThumbnail(named: name) }
    } else {
      await Self.update(id, content: content)
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      guard !Task.isCancelled else { return }
      await Self.end(id, content: content, dismissalPolicy: .after(Date().addingTimeInterval(linger)))
    }
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

  private nonisolated static func thumbnailName(for id: String) -> String {
    "ai-\(id).jpg"
  }

  private nonisolated static func removeThumbnail(named name: String) {
    guard let url = PrismLiveActivityFiles.url(named: name) else { return }
    try? FileManager.default.removeItem(at: url)
  }

  private nonisolated static func removeExpiredThumbnails() {
    guard let directory = PrismLiveActivityFiles.directory else { return }
    let cutoff = Date().addingTimeInterval(-(15 * 60 + 4))
    let files = (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.contentModificationDateKey]
    )) ?? []
    for file in files where file.lastPathComponent.hasPrefix("ai-") && file.pathExtension == "jpg" {
      guard let modifiedAt = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
            modifiedAt < cutoff
      else { continue }
      try? FileManager.default.removeItem(at: file)
    }
  }

  /// Live Activities cannot load from the network, so the app writes a small copy to the shared App Group container.
  private static func saveThumbnail(from url: URL?, named name: String) async -> String? {
    guard let url, let directory = PrismLiveActivityFiles.directory,
          let target = PrismLiveActivityFiles.url(named: name),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let scheme = components.scheme?.lowercased(), scheme == "https",
          components.host?.isEmpty == false, components.user == nil, components.password == nil
    else { return nil }

    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 8
    configuration.timeoutIntervalForResource = 8
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    guard let (download, response) = try? await session.download(for: URLRequest(url: url)) else { return nil }
    defer { try? FileManager.default.removeItem(at: download) }
    guard !Task.isCancelled,
          (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) == true,
          let finalURL = response.url,
          let finalComponents = URLComponents(url: finalURL, resolvingAgainstBaseURL: false),
          finalComponents.scheme?.lowercased() == "https", finalComponents.host?.isEmpty == false,
          finalComponents.user == nil, finalComponents.password == nil,
          let fileSize = (try? FileManager.default.attributesOfItem(atPath: download.path)[.size]) as? NSNumber,
          fileSize.doubleValue >= 0, fileSize.doubleValue <= 10 * 1024 * 1024,
          let source = CGImageSourceCreateWithURL(download as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 360,
          ] as CFDictionary)
    else { return nil }
    guard !Task.isCancelled else { return nil }
    let fileManager = FileManager.default
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      try? fileManager.removeItem(at: target)
      return nil
    }
    return name
  }
}
