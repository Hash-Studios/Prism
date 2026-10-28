import CoreMotion
import Flutter

/// Streams the phone's [pitch, roll] in radians from CoreMotion attitude while Dart listens.
final class PrismTiltStream: NSObject, FlutterStreamHandler {
  private let motion = CMMotionManager()
  private var generation = 0

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    _ = onCancel(withArguments: nil)
    guard motion.isDeviceMotionAvailable else {
      events(FlutterError(code: "NO_SENSOR", message: "Device motion is not available", details: nil))
      return nil
    }
    motion.deviceMotionUpdateInterval = 1.0 / 60.0
    let generation = self.generation
    motion.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
      guard let self, generation == self.generation else { return }
      if let error {
        _ = self.onCancel(withArguments: nil)
        events(FlutterError(code: "SENSOR_FAILED", message: error.localizedDescription, details: nil))
        return
      }
      guard let attitude = data?.attitude else { return }
      events([attitude.pitch, attitude.roll])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    generation += 1
    motion.stopDeviceMotionUpdates()
    return nil
  }
}
