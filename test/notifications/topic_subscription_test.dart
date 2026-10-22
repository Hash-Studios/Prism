import 'dart:async';

import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedMessaging extends Fake implements FirebaseMessaging {
  final calls = <String>[];
  final started = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    calls.add(topic);
    started.complete();
    await gate.future;
  }
}

void main() {
  test('a delayed legacy unsubscribe cannot dispatch its localized counterpart after ownership changes', () async {
    final messaging = _DelayedMessaging();
    bool current = true;
    final pending = unsubscribeFromTopicSafely(messaging, 'u_old', sourceTag: 'test', isCurrent: () => current);
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
