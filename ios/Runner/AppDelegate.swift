import Flutter
import UIKit

@main
@objc final class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    PrismMediaHostApiSetup.setUp(
      binaryMessenger: engineBridge.applicationRegistrar.messenger(),
      api: PrismMediaHostApiImpl()
    )
  }
}
