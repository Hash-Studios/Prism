import Flutter
import Foundation

/// Gives Dart the image that the Share Extension left in the App Group inbox.
enum PrismSharedInboxChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "prism/shared_inbox", binaryMessenger: messenger).setMethodCallHandler { call, result in
      guard let container = ShareInbox.containerURL() else {
        result(FlutterError(code: "missing", message: "No App Group container", details: nil))
        return
      }
      ShareInbox.sweep(container: container)
      switch call.method {
      case "directory":
        result(ShareInbox.folder(in: container).path)
      case "take":
        guard let id = call.arguments as? String, ShareInbox.isValidId(id) else {
          result(FlutterError(code: "invalid-id", message: "The shared item id is not valid", details: nil))
          return
        }
        do {
          let file = try ShareInbox.takeFile(forId: id, container: container)
          result(file.path)
        } catch {
          let code: String
          switch error as? ShareInbox.Failure {
          case .tooLarge: code = "too-large"
          case .missing: code = "missing"
          default: code = "unreadable"
          }
          result(FlutterError(code: code, message: "The shared image is not available", details: nil))
        }
      default:
        // Swift 6 rejects Flutter's FlutterMethodNotImplemented global. Dart only sends the two methods above.
        result(FlutterError(code: "unknown-method", message: "Unknown shared inbox method: \(call.method)", details: nil))
      }
    }
  }
}
