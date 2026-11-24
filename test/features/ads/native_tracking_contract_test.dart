import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native ATT asks on every scene or app activation until a final answer, one request at a time',
    () async {
      final String delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      final int start = delegate.indexOf('  private static func installTracking(');
      final int end = delegate.indexOf('  private static func clearBadge()', start);
      final int rule = delegate.indexOf('enum TrackingPrompt {');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      expect(rule, greaterThan(end));
      // Replace only the clock primitive. The production control flow and status mapping run unchanged.
      final String implementation = delegate
          .substring(start, end)
          .replaceAll('Task.sleep(nanoseconds:', 'TrackingClock.sleep(nanoseconds:');
      final Directory fixture = Directory.systemTemp.createTempSync('prism_tracking_contract_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      final File harness = File('${fixture.path}/tracking_contract.swift')
        ..writeAsStringSync(
          '$_swiftStubs\n${delegate.substring(rule)}\n@MainActor enum TrackingContract {\n$implementation\n$_swiftChecks\n}\n'
          'await TrackingContract.runChecks()\n',
        );
      final Process process = await Process.start('swift', <String>[
        '-swift-version',
        '6',
        '-strict-concurrency=complete',
        harness.path,
      ]);
      final Future<String> output = utf8.decoder.bind(process.stdout).join();
      final Future<String> errors = utf8.decoder.bind(process.stderr).join();
      final int exitCode = await process.exitCode.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      expect(exitCode, 0, reason: '${await output}\n${await errors}');
      expect((await output).trim(), 'native ATT lifecycle and persisted-status checks passed');
    },
    skip: !Platform.isMacOS ? 'Needs the installed macOS Swift toolchain; never installs one.' : false,
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

const String _swiftStubs = r'''
import Foundation
import os

typealias FlutterResult = (Any?) -> Void
protocol FlutterBinaryMessenger {}
extension Int: FlutterBinaryMessenger {}
final class FlutterMethodCall { let method = "request" }
final class FlutterError {
  init(code: String, message: String, details: Any?) {}
}
final class FlutterMethodChannel {
  nonisolated(unsafe) static var handler: ((FlutterMethodCall, @escaping FlutterResult) -> Void)?
  init(name: String, binaryMessenger: any FlutterBinaryMessenger) {}
  func setMethodCallHandler(_ handler: @escaping (FlutterMethodCall, @escaping FlutterResult) -> Void) {
    Self.handler = handler
  }
}

@MainActor final class NotificationCenter {
  static let `default` = NotificationCenter()
  private var observers: [(Notification.Name?, @Sendable (Notification) -> Void)] = []
  var observerCount: Int { observers.count }

  func addObserver(forName name: Notification.Name?, object: Any?, queue: OperationQueue?,
                   using block: @escaping @Sendable (Notification) -> Void) -> any NSObjectProtocol {
    observers.append((name, block))
    return NSObject()
  }

  func post(name: Notification.Name, object: Any?) {
    for (observedName, callback) in observers where observedName == name {
      callback(Notification(name: name, object: object))
    }
  }
}

final class UIScene: Sendable {
  enum ActivationState: Int, Sendable { case unattached = -1, foregroundActive, foregroundInactive, background }
  static let didActivateNotification = Notification.Name("tracking-contract-scene-active")
  static let willDeactivateNotification = Notification.Name("tracking-contract-scene-inactive")
  let activationState: ActivationState
  init(_ activationState: ActivationState) { self.activationState = activationState }
}

@MainActor final class UIApplication {
  enum State { case active, inactive, background }
  static let shared = UIApplication()
  static let didBecomeActiveNotification = Notification.Name("tracking-contract-active")
  static let willResignActiveNotification = Notification.Name("tracking-contract-resign")
  var applicationState = State.active
  // One window scene, as in the app's UIApplicationSceneManifest. Its state follows the app state.
  var connectedScenes: [UIScene] {
    switch applicationState {
    case .active: return [UIScene(.foregroundActive)]
    case .inactive: return [UIScene(.foregroundInactive)]
    case .background: return [UIScene(.background)]
    }
  }
}

@MainActor enum ATTrackingManager {
  enum AuthorizationStatus { case authorized, denied, restricted, notDetermined }
  static var trackingAuthorizationStatus = AuthorizationStatus.notDetermined
  static var requestCount = 0
  static var requestSleepCounts: [Int] = []
  static var requestStates: [UIApplication.State] = []
  static var onRequest: ((@escaping (AuthorizationStatus) -> Void) -> Void)?

  static func requestTrackingAuthorization(completionHandler: @escaping (AuthorizationStatus) -> Void) {
    requestCount += 1
    requestSleepCounts.append(TrackingClock.sleepCount)
    requestStates.append(UIApplication.shared.applicationState)
    onRequest?(completionHandler)
  }

  // Keep the previous async implementation compilable so its behavioral failures are visible too.
  static func requestTrackingAuthorization() async -> AuthorizationStatus {
    await withCheckedContinuation { continuation in
      requestTrackingAuthorization { continuation.resume(returning: $0) }
    }
  }
}

@MainActor enum TrackingClock {
  static var sleepCount = 0
  static var sleeping = 0
  static var maxSleeping = 0
  static var onSleep: (() throws -> Void)?
  static func sleep(nanoseconds: UInt64) async throws {
    precondition(nanoseconds > 0, "Polling must yield between attempts")
    sleepCount += 1
    precondition(sleepCount <= 100, "Tracking wait must be bounded")
    try onSleep?()
    sleeping += 1
    maxSleeping = max(maxSleeping, sleeping)
    await Task.yield()
    sleeping -= 1
  }
}
''';

const String _swiftChecks = r'''
  static func reset(_ state: UIApplication.State = .active) {
    UIApplication.shared.applicationState = state
    ATTrackingManager.trackingAuthorizationStatus = .notDetermined
    ATTrackingManager.requestCount = 0
    ATTrackingManager.requestSleepCounts = []
    ATTrackingManager.requestStates = []
    ATTrackingManager.onRequest = nil
    trackingAnswered = trackingAsked
    TrackingClock.sleepCount = 0
    TrackingClock.maxSleeping = 0
    TrackingClock.onSleep = nil
  }

  static func expectStatus(_ expected: ATTrackingManager.AuthorizationStatus,
                           _ message: String = "Unexpected persisted tracking status") async {
    let actual = await requestTracking(trigger: "test")
    precondition(actual == expected, message)
  }

  static func channelRequest() async -> String {
    await withCheckedContinuation { continuation in
      FlutterMethodChannel.handler!(FlutterMethodCall()) { result in
        continuation.resume(returning: result as! String)
      }
    }
  }

  static func resignActive(_ state: UIApplication.State = .inactive) async {
    UIApplication.shared.applicationState = state
    NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    for _ in 0..<20 { await Task.yield() }
  }

  static func becomeActive(_ name: Notification.Name = UIApplication.didBecomeActiveNotification) async {
    UIApplication.shared.applicationState = .active
    let before = TrackingClock.sleepCount
    NotificationCenter.default.post(name: name, object: nil)
    for _ in 0..<500 {
      if trackingRequest == nil && TrackingClock.sleepCount > before { return }
      await Task.yield()
    }
  }

  static func runChecks() async {
    observeActivationForTracking()
    installTracking(on: 0)
    installTracking(on: 1)
    observeActivationForTracking()
    precondition(NotificationCenter.default.observerCount == 4,
                 "Scene and app observers for activation and deactivation; recreating the Flutter engine adds none")

    reset()
    ATTrackingManager.onRequest = { callback in
      ATTrackingManager.trackingAuthorizationStatus = .authorized
      callback(.authorized)
    }
    await expectStatus(.authorized)
    precondition(ATTrackingManager.requestSleepCounts.first! > 0,
                 "Even an active app must settle before showing ATT")
    precondition(ATTrackingManager.requestCount == 1)

    let terminalStatuses: [(ATTrackingManager.AuthorizationStatus, String)] = [
      (.authorized, "authorized"), (.denied, "denied"), (.restricted, "restricted")
    ]
    for (status, name) in terminalStatuses {
      reset(.background)
      ATTrackingManager.trackingAuthorizationStatus = status
      await expectStatus(status)
      await becomeActive()
      precondition(ATTrackingManager.requestCount == 0 && TrackingClock.sleepCount == 0,
                   "A final answer must never be asked again, on a request or on activation")
      precondition(trackingName(status) == name)
    }
    precondition(trackingName(.notDetermined) == "notDetermined")

    for state in [UIApplication.State.inactive, .background] {
      reset(state)
      await expectStatus(.notDetermined)
      precondition(ATTrackingManager.requestCount == 0,
                   "No request while another system prompt or the background holds the app")
    }

    reset(.inactive)
    await expectStatus(.notDetermined)
    ATTrackingManager.onRequest = { callback in
      ATTrackingManager.trackingAuthorizationStatus = .denied
      callback(.denied)
    }
    await becomeActive()
    precondition(ATTrackingManager.requestCount == 1,
                 "The next activation asks again after the first attempt found the app inactive")
    precondition(ATTrackingManager.requestStates.allSatisfy { $0 == .active })
    await becomeActive()
    await becomeActive()
    precondition(ATTrackingManager.requestCount == 1, "No prompt loop after a denial")

    reset(.background)
    ATTrackingManager.onRequest = { callback in
      ATTrackingManager.trackingAuthorizationStatus = .authorized
      callback(.authorized)
    }
    await becomeActive(UIScene.didActivateNotification)
    precondition(ATTrackingManager.requestCount == 1,
                 "A scene activation alone asks, for UIScene apps where the app-level signal is late or missing")
    precondition(ATTrackingManager.requestStates.allSatisfy { $0 == .active })

    reset()
    ATTrackingManager.onRequest = { _ in UIApplication.shared.applicationState = .inactive }
    await becomeActive()
    await resignActive()
    await becomeActive()
    precondition(ATTrackingManager.requestCount == 2,
                 "Every activation asks again while the answer is still notDetermined")

    reset()
    ATTrackingManager.onRequest = { callback in
      ATTrackingManager.trackingAuthorizationStatus = .authorized
      callback(.authorized)
    }
    async let first = channelRequest()
    async let second = channelRequest()
    NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    let answers = await [first, second]
    precondition(answers == ["authorized", "authorized"] && ATTrackingManager.requestCount == 1,
                 "Concurrent callers get the same answer")
    precondition(TrackingClock.maxSleeping == 1, "Concurrent callers share one request loop")

    reset()
    ATTrackingManager.onRequest = { callback in
      if ATTrackingManager.requestCount == 1 {
        // iOS can complete early without recording a user decision.
        callback(.denied)
      } else {
        ATTrackingManager.trackingAuthorizationStatus = .authorized
        callback(.notDetermined)
      }
    }
    await expectStatus(.authorized, "Persisted status wins over an early or stale callback")
    precondition(ATTrackingManager.requestCount == 2,
                 "A dropped request is retried while the app stays active")

    reset()
    ATTrackingManager.onRequest = { _ in
      UIApplication.shared.applicationState = .inactive
      // The system callback never arrives.
    }
    await expectStatus(.notDetermined, "A missing system callback must not strand the Flutter result")
    precondition(ATTrackingManager.requestCount == 1)
    ATTrackingManager.trackingAuthorizationStatus = .authorized
    UIApplication.shared.applicationState = .active
    await expectStatus(.authorized, "A recorded decision resolves even when the callback never arrives")
    precondition(ATTrackingManager.requestCount == 1)

    reset()
    ATTrackingManager.onRequest = { callback in callback(.authorized) }
    await expectStatus(.notDetermined, "A callback alone cannot claim a recorded tracking decision")
    precondition(ATTrackingManager.requestCount > 0)

    reset()
    // The alert is on screen: the app stays active and the callback waits for the user.
    ATTrackingManager.onRequest = { _ in }
    await expectStatus(.notDetermined)
    precondition(ATTrackingManager.requestCount == 1, "No second request while the first one is unanswered")
    ATTrackingManager.onRequest = { callback in
      ATTrackingManager.trackingAuthorizationStatus = .denied
      callback(.denied)
    }
    await becomeActive()
    precondition(ATTrackingManager.requestCount == 1,
                 "A late second activation signal must not send a request on top of the visible alert")
    await resignActive()
    await becomeActive()
    precondition(ATTrackingManager.requestCount == 2,
                 "After the app lost the foreground, a request with no callback does not block the next one")

    reset()
    TrackingClock.onSleep = { throw CancellationError() }
    await expectStatus(.notDetermined)
    precondition(ATTrackingManager.requestCount == 0,
                 "Cancelled waits must not present a prompt")
    print("native ATT lifecycle and persisted-status checks passed")
  }
''';
