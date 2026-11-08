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

  @override
  Future<String?> getAPNSToken() async => 'test-apns-token';

  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) {
    tokenReads++;
    return Completer<String?>().future;
  }

  @override
  Future<void> subscribeToTopic(String topic) {
    topicCalls++;
    return Completer<void>().future;
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) {
    topicCalls++;
    return Completer<void>().future;
  }
}

void main() {
  setUp(resetFcmTokenGuard);
  tearDown(() => topicCallsNeedFcmToken = defaultTopicCallsNeedFcmToken);

  group('FCM that never answers', () {
    test('a subscribe returns false after the timeout', () {
      fakeAsync((FakeAsync async) {
        bool? joined;
        subscribeToTopicSafely(_SilentMessaging(), 'drops', sourceTag: 'test').then((bool ok) => joined = ok);
        async.elapse(fcmCallTimeout - const Duration(milliseconds: 1));
        expect(joined, isNull);
        async.elapse(const Duration(seconds: 1));
        expect(joined, isFalse);
      });
    });

    test('an unsubscribe completes after the timeout', () {
      fakeAsync((FakeAsync async) {
        bool done = false;
        unsubscribeFromTopicSafely(_SilentMessaging(), 'drops', sourceTag: 'test').then((_) => done = true);
        async.elapse(fcmCallTimeout + const Duration(seconds: 1));
        expect(done, isTrue);
      });
    });

    test('a token read returns null after the timeout, and later reads do not wait again', () {
      fakeAsync((FakeAsync async) {
        final _SilentMessaging messaging = _SilentMessaging();
        final List<String?> tokens = <String?>[];
        readFcmToken(messaging).then(tokens.add);
        async.elapse(fcmCallTimeout + const Duration(seconds: 1));
        expect(tokens, <String?>[null]);
        readFcmToken(messaging).then(tokens.add);
        async.flushMicrotasks();
        expect(tokens, <String?>[null, null]);
        expect(messaging.tokenReads, 1);
      });
    });

    test('where topics need an FCM token, a silent token stops every topic call before FCM', () {
      topicCallsNeedFcmToken = () => true;
      fakeAsync((FakeAsync async) {
        final _SilentMessaging messaging = _SilentMessaging();
        final List<bool> results = <bool>[];
        subscribeToTopicSafely(messaging, 'drops', sourceTag: 'test').then(results.add);
        async.elapse(fcmCallTimeout + const Duration(seconds: 1));
        subscribeToTopicSafely(messaging, 'recommendations', sourceTag: 'test').then(results.add);
        async.flushMicrotasks();
        expect(results, <bool>[false, false]);
        expect(messaging.topicCalls, 0);
        expect(messaging.tokenReads, 1);
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
