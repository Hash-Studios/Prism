import AppTrackingTransparency
import Flutter
import os
import UIKit
import UserNotifications
import WidgetKit

@main
@objc final class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
      Self.prepareOfflineRoot(at: supportDirectory)
    }
    Self.observeActivationForTracking()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @discardableResult
  static func prepareOfflineRoot(at supportDirectory: URL, fileManager: FileManager = .default) -> URL? {
    let root = supportDirectory.appendingPathComponent("prism/offline", isDirectory: true)
    do {
      try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var mutableRoot = root
      try mutableRoot.setResourceValues(values)
      return try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true ? root : nil
    } catch {
      return nil
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    PrismMediaHostApiSetup.setUp(
      binaryMessenger: engineBridge.applicationRegistrar.messenger(),
      api: PrismMediaHostApiImpl()
    )
    PrismAppIconHostApiSetup.setUp(
      binaryMessenger: engineBridge.applicationRegistrar.messenger(),
      api: PrismAppIconHostApiImpl()
    )
    PrismShareHostApiSetup.setUp(
      binaryMessenger: engineBridge.applicationRegistrar.messenger(),
      api: PrismShareHostApiImpl()
    )
    let messenger = engineBridge.applicationRegistrar.messenger()
    PrismLiveActivityHostApiSetup.setUp(
      binaryMessenger: messenger,
      api: PrismLiveActivityHostApiImpl(flutterApi: PrismLiveActivityFlutterApi(binaryMessenger: messenger))
    )
    FlutterEventChannel(name: "prism/tilt", binaryMessenger: messenger).setStreamHandler(PrismTiltStream())
    PrismSharedInboxChannel.register(with: messenger)
    PrismWidgetHostApiSetup.setUp(binaryMessenger: messenger, api: PrismWidgetHostApiImpl())
    PrismLivePhotoHostApiSetup.setUp(
      binaryMessenger: messenger,
      api: PrismLivePhotoHostApiImpl(flutterApi: PrismLivePhotoFlutterApi(binaryMessenger: messenger))
    )
    FlutterMethodChannel(name: "prism/power", binaryMessenger: messenger).setMethodCallHandler { call, result in
      if call.method == "lowPowerMode" {
        result(ProcessInfo.processInfo.isLowPowerModeEnabled)
      } else {
        result(FlutterError(code: "UNKNOWN_METHOD", message: call.method, details: nil))
      }
    }
    Self.installTracking(on: messenger)
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { _ in
      Task { @MainActor in
        AppDelegate.clearBadge()
        WidgetCenter.shared.reloadTimelines(ofKind: PrismWidgetKind.wallOfTheDay)
      }
    }
  }

  @MainActor
  private static func installTracking(on messenger: any FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "prism/tracking", binaryMessenger: messenger).setMethodCallHandler { call, result in
      guard call.method == "request" else {
        result(FlutterError(code: "UNKNOWN_METHOD", message: call.method, details: nil))
        return
      }
      Task { @MainActor in
        result(Self.trackingName(await Self.requestTracking(trigger: "flutter")))
      }
    }
  }

  /// The app uses the UIScene life cycle, so the scene activation is the real "on screen and active" moment.
  /// The app-level notification stays as a second trigger. Both join the same request.
  @MainActor
  private static func observeActivationForTracking() {
    guard trackingObservers.isEmpty else { return }
    let triggers: [(Notification.Name, String)] = [
      (UIScene.didActivateNotification, "scene"),
      (UIApplication.didBecomeActiveNotification, "app"),
    ]
    trackingObservers = triggers.map { name, trigger in
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
        Task { @MainActor in _ = await Self.requestTracking(trigger: trigger) }
      }
    }
  }

  @MainActor private static var trackingObservers: [any NSObjectProtocol] = []
  @MainActor private static var trackingRequest: Task<ATTrackingManager.AuthorizationStatus, Never>?
  nonisolated private static let trackingLog = Logger(subsystem: "com.hash.prism", category: "ATT")

  @MainActor
  private static func requestTracking(trigger: String) async -> ATTrackingManager.AuthorizationStatus {
    if let pending = trackingRequest { return await pending.value }
    let request = Task { await askForTracking(trigger: trigger) }
    trackingRequest = request
    let status = await request.value
    trackingRequest = nil
    return status
  }

  /// iOS drops requests made too early or while another alert is up, so ask again every 250 ms while the status is
  /// notDetermined and a scene is foreground-active. A request already on screen is not shown twice. Leaving the
  /// foreground ends the attempt; the next activation starts a new one.
  @MainActor
  private static func askForTracking(trigger: String) async -> ATTrackingManager.AuthorizationStatus {
    for attempt in 1...40 {
      guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
        return ATTrackingManager.trackingAuthorizationStatus
      }
      do {
        try await Task.sleep(nanoseconds: 250_000_000)
      } catch {
        return ATTrackingManager.trackingAuthorizationStatus
      }
      let status = ATTrackingManager.trackingAuthorizationStatus
      let scenes = UIApplication.shared.connectedScenes.map(\.activationState)
      let ask = TrackingPrompt.shouldAsk(status: status, sceneStates: scenes)
      if attempt == 1 || !ask {
        trackingLog.log(
          "\(trigger, privacy: .public) #\(attempt) status=\(trackingName(status), privacy: .public) scenes=\(scenes.map(\.rawValue), privacy: .public) ask=\(ask)"
        )
      }
      guard ask else { return status }
      // Read the persisted status on the next turn; early callbacks can precede the user's decision.
      ATTrackingManager.requestTrackingAuthorization { answer in
        trackingLog.log("callback \(trackingName(answer), privacy: .public)")
      }
    }
    return ATTrackingManager.trackingAuthorizationStatus
  }

  nonisolated static func trackingName(_ status: ATTrackingManager.AuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unknown"
    }
  }

  private static func clearBadge() {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      UIApplication.shared.applicationIconBadgeNumber = 0
    }
  }
}

/// iOS shows the ATT alert only while the status is notDetermined and a scene is foreground-active.
/// A request made at any other time is dropped without an alert.
enum TrackingPrompt {
  static func shouldAsk(status: ATTrackingManager.AuthorizationStatus, sceneStates: [UIScene.ActivationState]) -> Bool {
    status == .notDetermined && sceneStates.contains(.foregroundActive)
  }
}
