import AppTrackingTransparency
import Flutter
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
    FlutterMethodChannel(name: "prism/tracking", binaryMessenger: messenger).setMethodCallHandler { call, result in
      guard call.method == "request" else {
        result(FlutterError(code: "UNKNOWN_METHOD", message: call.method, details: nil))
        return
      }
      Task { @MainActor in
        result(Self.trackingName(await Self.requestTracking()))
      }
    }
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

  /// Waits for an active app and retries ATT requests suppressed by another permission prompt.
  @MainActor
  private static func requestTracking() async -> ATTrackingManager.AuthorizationStatus {
    guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
      return ATTrackingManager.trackingAuthorizationStatus
    }
    for _ in 0..<40 {
      do {
        try await Task.sleep(nanoseconds: 250_000_000)
      } catch {
        return ATTrackingManager.trackingAuthorizationStatus
      }
      let status = ATTrackingManager.trackingAuthorizationStatus
      guard status == .notDetermined else { return status }
      guard UIApplication.shared.applicationState == .active else { continue }
      // Read the persisted status on the next turn; early callbacks can precede the user's decision.
      ATTrackingManager.requestTrackingAuthorization { _ in }
    }
    return ATTrackingManager.trackingAuthorizationStatus
  }

  private static func trackingName(_ status: ATTrackingManager.AuthorizationStatus) -> String {
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
