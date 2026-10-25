import Flutter
import UIKit
import UserNotifications

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
    let messenger = engineBridge.applicationRegistrar.messenger()
    PrismLiveActivityHostApiSetup.setUp(
      binaryMessenger: messenger,
      api: PrismLiveActivityHostApiImpl(flutterApi: PrismLiveActivityFlutterApi(binaryMessenger: messenger))
    )
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { _ in
      Task { @MainActor in
        AppDelegate.clearBadge()
      }
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
