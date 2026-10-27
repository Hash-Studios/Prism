import CoreMotion
import Flutter

/// Streams the phone's [pitch, roll] in radians from CoreMotion attitude while Dart listens.
final class PrismTiltStream: NSObject, FlutterStreamHandler {
  private let motion = CMMotionManager()

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard motion.isDeviceMotionAvailable else {
      return FlutterError(code: "NO_SENSOR", message: "Device motion is not available", details: nil)
    }
    motion.deviceMotionUpdateInterval = 1.0 / 60.0
    motion.startDeviceMotionUpdates(to: .main) { data, _ in
      guard let attitude = data?.attitude else { return }
      events([attitude.pitch, attitude.roll])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motion.stopDeviceMotionUpdates()
    return nil
  }
}
