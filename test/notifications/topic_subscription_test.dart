import 'dart:async';

import 'package:Prism/notifications/topic_subscription.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedMessaging extends Fake implements FirebaseMessaging {
  final calls = <String>[];
  final started = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<String?> getAPNSToken() async => 'test-apns-token';

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    calls.add(topic);
    started.complete();
    await gate.future;
  }
}

/// FCM on a phone without Google Play services: no call ever answers.
class _SilentMessaging extends Fake implements FirebaseMessaging {
  int tokenReads = 0;
  int topicCalls = 0;
  bool completeTopicCalls = false;
  Future<String?> Function()? getTokenHandler;

  @override
  Future<String?> getAPNSToken() async => 'test-apns-token';

  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) {
    tokenReads++;
    return getTokenHandler?.call() ?? Completer<String?>().future;
  }

  @override
  Future<void> subscribeToTopic(String topic) {
    topicCalls++;
    return completeTopicCalls ? Future<void>.value() : Completer<void>().future;
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) {
    topicCalls++;
    return completeTopicCalls ? Future<void>.value() : Completer<void>().future;
  }
}

void main() {
  group('Android without Google Play services (#249, #552)', () {
    // The error firebase_messaging gave on the API 30 emulator with no Play services, 2026-11-08.
    const String noPlayServices = '[firebase_messaging/unknown] java.io.IOException: MISSING_INSTANCEID_SERVICE';

    setUp(() => topicCallsCheckPlayServices = () => true);
    tearDown(() {
      topicCallsCheckPlayServices = defaultTopicCallsCheckPlayServices;
    });

    test('topic calls skip FCM at once for the rest of the run', () {
      fakeAsync((FakeAsync async) {
        final _SilentMessaging messaging = _SilentMessaging()
          ..getTokenHandler = () => Future<String?>.error(Exception(noPlayServices));
        final List<bool> results = <bool>[];
        subscribeToTopicSafely(messaging, 'drops', sourceTag: 'test').then(results.add);
        unsubscribeFromTopicSafely(messaging, 'recommendations', sourceTag: 'test').then((_) => results.add(false));
        async.flushMicrotasks();
        expect(results, <bool>[false, false]);
        expect(messaging.topicCalls, 0);
        expect(messaging.tokenReads, 1);
        subscribeToTopicSafely(messaging, 'another', sourceTag: 'test');
        async.flushMicrotasks();
        expect(messaging.tokenReads, 1);
        expect(messaging.topicCalls, 0);
      });
    });

    test('concurrent first topic calls share one pending Play services probe', () {
      fakeAsync((FakeAsync async) {
        final Completer<String?> token = Completer<String?>();
        final _SilentMessaging messaging = _SilentMessaging()
          ..completeTopicCalls = true
          ..getTokenHandler = () => token.future;
        final List<bool> results = <bool>[];
        subscribeToTopicSafely(messaging, 'first', sourceTag: 'test').then(results.add);
        unsubscribeFromTopicSafely(messaging, 'second', sourceTag: 'test').then((_) => results.add(true));
        async.flushMicrotasks();
        expect(messaging.tokenReads, 1);
        expect(messaging.topicCalls, 0);

        token.complete('present-token');
        async.flushMicrotasks();
        expect(messaging.tokenReads, 1);
        expect(messaging.topicCalls, 4);
        expect(results, <bool>[true, true]);
      });
    });

    test('successful and null probe results are retried on later calls', () {
      fakeAsync((FakeAsync async) {
        final _SilentMessaging messaging = _SilentMessaging()..completeTopicCalls = true;
        final List<String?> tokens = <String?>['first-token', null];
        final List<bool> results = <bool>[];
        messaging.getTokenHandler = () async => tokens.removeAt(0);

        subscribeToTopicSafely(messaging, 'first', sourceTag: 'test').then(results.add);
        async.flushMicrotasks();
        expect(messaging.tokenReads, 1);
        expect(messaging.topicCalls, 2);

        subscribeToTopicSafely(messaging, 'second', sourceTag: 'test').then(results.add);
        async.flushMicrotasks();
        expect(messaging.tokenReads, 2);
        expect(messaging.topicCalls, 4);
        expect(results, <bool>[true, true]);
      });
    });

    test('a late missing-services error after timeout does not latch failure', () {
      fakeAsync((FakeAsync async) {
        final Completer<String?> lateToken = Completer<String?>();
        final _SilentMessaging messaging = _SilentMessaging()
          ..completeTopicCalls = true
          ..getTokenHandler = () => lateToken.future;
        final List<bool> results = <bool>[];
        subscribeToTopicSafely(messaging, 'slow', sourceTag: 'test').then(results.add);
        async.flushMicrotasks();
        async.elapse(fcmCallTimeout + const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(messaging.topicCalls, 2);

        lateToken.completeError(Exception(noPlayServices));
        async.flushMicrotasks();
        messaging.getTokenHandler = () async => 'recovered-token';
        subscribeToTopicSafely(messaging, 'recovered', sourceTag: 'test').then(results.add);
        async.flushMicrotasks();
        expect(messaging.tokenReads, 2);
        expect(messaging.topicCalls, 4);
        expect(results, <bool>[true, true]);
      });
    });

    test('ownership loss while the probe is pending prevents topic dispatch', () {
      fakeAsync((FakeAsync async) {
        final Completer<String?> token = Completer<String?>();
        final _SilentMessaging messaging = _SilentMessaging()
          ..completeTopicCalls = true
          ..getTokenHandler = () => token.future;
        bool isCurrent = true;
        final List<bool> results = <bool>[];
        subscribeToTopicSafely(messaging, 'owned', sourceTag: 'test', isCurrent: () => isCurrent).then(results.add);
        async.flushMicrotasks();
        expect(messaging.tokenReads, 1);

        isCurrent = false;
        token.complete('present-token');
        async.flushMicrotasks();
        expect(results, <bool>[false]);
        expect(messaging.topicCalls, 0);
      });
    });

    test('a stale probe completing after reset cannot replace a newer probe', () {
      fakeAsync((FakeAsync async) {
        final Completer<String?> oldToken = Completer<String?>();
        final Completer<String?> newToken = Completer<String?>();
        final _SilentMessaging messaging = _SilentMessaging()
          ..completeTopicCalls = true
          ..getTokenHandler = () => oldToken.future;
        final List<bool> results = <bool>[];
        subscribeToTopicSafely(messaging, 'old', sourceTag: 'test').then(results.add);
        async.flushMicrotasks();
        expect(messaging.tokenReads, 1);

        topicCallsCheckPlayServices = () => true;
        messaging.getTokenHandler = () => newToken.future;
        subscribeToTopicSafely(messaging, 'new', sourceTag: 'test').then(results.add);
        async.flushMicrotasks();
        expect(messaging.tokenReads, 2);
        expect(messaging.topicCalls, 0);

        oldToken.complete('old-token');
        async.flushMicrotasks();
        expect(messaging.topicCalls, 2);
        subscribeToTopicSafely(messaging, 'after-stale', sourceTag: 'test').then(results.add);
        async.flushMicrotasks();
        expect(messaging.tokenReads, 2);
        expect(messaging.topicCalls, 2);

        newToken.complete('new-token');
        async.flushMicrotasks();
        expect(messaging.topicCalls, 6);
        expect(results, <bool>[true, true, true]);
      });
    });

    test('another token failure, as on an offline Play phone, does not stop topic calls', () {
      fakeAsync((FakeAsync async) {
        final _SilentMessaging messaging = _SilentMessaging()
          ..getTokenHandler = () => Future<String?>.error(Exception('SERVICE_NOT_AVAILABLE'));
        subscribeToTopicSafely(messaging, 'drops', sourceTag: 'test');
        async.flushMicrotasks();
        subscribeToTopicSafely(messaging, 'recommendations', sourceTag: 'test');
        async.flushMicrotasks();
        expect(messaging.topicCalls, 2);
        expect(messaging.tokenReads, 2);
        async.elapse(fcmCallTimeout * 3);
      });
    });
  });

  group('FCM that never answers', () {
    test('a subscribe returns false after the timeout', () {
      fakeAsync((FakeAsync async) {
        bool? joined;
        subscribeToTopicSafely(_SilentMessaging(), 'drops', sourceTag: 'test').then((bool ok) => joined = ok);
        async.elapse(fcmCallTimeout - const Duration(milliseconds: 1));
        expect(joined, isNull);
        async.elapse(fcmCallTimeout * 2 + const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(joined, isFalse);
      });
    });

    test('an unsubscribe completes after the timeout', () {
      fakeAsync((FakeAsync async) {
        bool done = false;
        unsubscribeFromTopicSafely(_SilentMessaging(), 'drops', sourceTag: 'test').then((_) => done = true);
        async.elapse(fcmCallTimeout * 2 + const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(done, isTrue);
      });
    });

    test('a token read returns null after the timeout but later reads can recover', () {
      fakeAsync((FakeAsync async) {
        final _SilentMessaging messaging = _SilentMessaging();
        final List<String?> tokens = <String?>[];
        readFcmToken(messaging).then(tokens.add);
        async.elapse(fcmCallTimeout * 2 + const Duration(seconds: 1));
        expect(tokens, <String?>[null]);
        messaging.getTokenHandler = () async => 'recovered-token';
        readFcmToken(messaging).then(tokens.add);
        async.flushMicrotasks();
        expect(tokens, <String?>[null, 'recovered-token']);
        expect(messaging.tokenReads, 2);
      });
    });

    test('topic changes are dispatched without waiting for a token and both topic variants are attempted', () {
      fakeAsync((FakeAsync async) {
        final _SilentMessaging messaging = _SilentMessaging();
        bool done = false;
        unsubscribeFromTopicSafely(messaging, 'drops', sourceTag: 'test').then((_) => done = true);
        async.flushMicrotasks();
        expect(messaging.topicCalls, 1);
        expect(messaging.tokenReads, 0);
        async.elapse(fcmCallTimeout * 2 + const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(done, isTrue);
        expect(messaging.topicCalls, 2);
      });
    });
  });

  test('a delayed legacy unsubscribe cannot dispatch its localized counterpart after ownership changes', () async {
    final messaging = _DelayedMessaging();
    bool current = true;
    final pending = unsubscribeFromTopicSafely(messaging, 'u_old', sourceTag: 'test', isCurrent: () => current);
    addTearDown(() async {
      current = false;
      if (!messaging.gate.isCompleted) messaging.gate.complete();
      await pending;
    });
    await messaging.started.future;
    current = false;
    messaging.gate.complete();
    await pending;
    expect(messaging.calls, <String>['u_old']);
  });

  group('followersTopicFromEmail', () {
    test('returns null when email local part is empty', () {
      expect(followersTopicFromEmail('   @example.com'), isNull);
      expect(followersTopicFromEmail('   '), isNull);
    });

    test('removes characters that are invalid for FCM topics', () {
      expect(followersTopicFromEmail('john+alerts.test@example.com'), 'johnalerts.test');
      expect(followersTopicFromEmail(' name with space+tag@example.com '), 'namewithspacetag');
    });

    test('returns null when sanitization removes all characters', () {
      expect(followersTopicFromEmail('++@example.com'), isNull);
    });

    test('keeps supported FCM topic characters in local part', () {
      expect(followersTopicFromEmail('Az-_.~%09@example.com'), 'Az-_.~%09');
    });
  });

  group('userTopicFromId', () {
    test('prefixes and sanitizes the uid', () {
      expect(userTopicFromId(' uid+with space '), 'u_uidwithspace');
      expect(userTopicFromId('   '), isNull);
    });
  });
}
