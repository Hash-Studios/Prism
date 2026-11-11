import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native ATT settles, retries unresolved prompts, and finishes without a callback or activation',
    () async {
      final String delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      final RegExpMatch? trackingFunction = RegExp(
        r'^  (?:@MainActor\n  )?private static func requestTracking\(\)',
        multiLine: true,
      ).firstMatch(delegate);
      expect(trackingFunction, isNotNull);
      final int start = trackingFunction!.start;
      final int end = delegate.indexOf('  private static func clearBadge()', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      // Replace only the clock primitive. The production control flow and status mapping run unchanged.
      final String implementation = delegate
          .substring(start, end)
          .replaceAll('Task.sleep(nanoseconds:', 'TrackingClock.sleep(nanoseconds:');
      final int channelStart = delegate.indexOf('    FlutterMethodChannel(name: "prism/tracking"');
      final int channelEnd = delegate.indexOf('    NotificationCenter.default.addObserver(', channelStart);
      expect(channelStart, greaterThanOrEqualTo(0));
      expect(channelEnd, greaterThan(channelStart));
      final String channel = delegate.substring(channelStart, channelEnd);
      final Directory fixture = Directory.systemTemp.createTempSync('prism_tracking_contract_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      final File harness = File('${fixture.path}/tracking_contract.swift')
        ..writeAsStringSync(
          '$_swiftStubs\n@MainActor enum TrackingContract {\n$implementation\n'
          'static func installChannel() { let messenger = 0\n$channel\n}\n$_swiftChecks\n}\n'
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

typealias FlutterResult = (Any?) -> Void
final class FlutterMethodCall { let method = "request" }
final class FlutterError {
  init(code: String, message: String, details: Any?) {}
}
final class FlutterMethodChannel {
  init(name: String, binaryMessenger: Int) {}
  func setMethodCallHandler(_ handler: @escaping (FlutterMethodCall, @escaping FlutterResult) -> Void) {}
}

@MainActor final class UIApplication {
  enum State { case active, inactive, background }
  static let shared = UIApplication()
  static let didBecomeActiveNotification = Notification.Name("tracking-contract-active")
  var applicationState = State.active
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
  static var onSleep: (() throws -> Void)?
  static func sleep(nanoseconds: UInt64) async throws {
    precondition(nanoseconds > 0, "Polling must yield between attempts")
    sleepCount += 1
    precondition(sleepCount <= 100, "Tracking wait must be bounded")
    try onSleep?()
    await Task.yield()
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
    TrackingClock.sleepCount = 0
    TrackingClock.onSleep = nil
  }

  static func expectStatus(_ expected: ATTrackingManager.AuthorizationStatus,
                           _ message: String = "Unexpected persisted tracking status") async {
    let actual = await requestTracking()
    precondition(actual == expected, message)
  }

  static func runChecks() async {
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
      precondition(ATTrackingManager.requestCount == 0 && TrackingClock.sleepCount == 0,
                   "A terminal status must not wait for activation or ask again")
      precondition(trackingName(status) == name)
    }
    precondition(trackingName(.notDetermined) == "notDetermined")

    reset(.background)
    await expectStatus(.notDetermined)
    precondition(ATTrackingManager.requestCount == 0 && TrackingClock.sleepCount > 0,
                 "No activation must finish unresolved without requesting ATT")

    reset()
    TrackingClock.onSleep = {
      if TrackingClock.sleepCount == 1 { UIApplication.shared.applicationState = .inactive }
      if TrackingClock.sleepCount == 3 { UIApplication.shared.applicationState = .active }
    }
    ATTrackingManager.onRequest = { callback in
      ATTrackingManager.trackingAuthorizationStatus = .denied
      callback(.denied)
    }
    await expectStatus(.denied)
    precondition(ATTrackingManager.requestSleepCounts.first! >= 3)
    precondition(ATTrackingManager.requestStates.allSatisfy { $0 == .active },
                 "Recheck activity after the settling delay")

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
                 "A suppressed permission prompt must be retried")

    reset()
    ATTrackingManager.onRequest = { _ in
      UIApplication.shared.applicationState = .inactive
      // The system callback never arrives.
    }
    await expectStatus(.notDetermined, "A missing system callback must not strand the Flutter result")
    precondition(ATTrackingManager.requestCount == 1)

    reset()
    ATTrackingManager.onRequest = { _ in UIApplication.shared.applicationState = .inactive }
    TrackingClock.onSleep = {
      if TrackingClock.sleepCount == 3 {
        ATTrackingManager.trackingAuthorizationStatus = .authorized
        UIApplication.shared.applicationState = .active
      }
    }
    await expectStatus(.authorized, "A recorded decision must resolve even when the callback never arrives")
    precondition(ATTrackingManager.requestCount == 1)

    reset()
    ATTrackingManager.onRequest = { callback in callback(.authorized) }
    await expectStatus(.notDetermined, "A callback alone cannot claim a recorded tracking decision")
    precondition(ATTrackingManager.requestCount > 0)

    reset()
    TrackingClock.onSleep = { throw CancellationError() }
    await expectStatus(.notDetermined)
    precondition(ATTrackingManager.requestCount == 0,
                 "Cancelled waits must not present a prompt")
    print("native ATT lifecycle and persisted-status checks passed")
  }
''';
