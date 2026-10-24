import 'dart:async';
import 'dart:io';

import 'package:Prism/notifications/topic_subscription.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMessaging implements FirebaseMessaging {
  final List<String> subscribed = <String>[];
  final List<String> unsubscribed = <String>[];
  Completer<void>? unsubscribeGate;
  String? failingUnsubscribeTopic;
  String? apnsToken = 'apns';
  int apnsTokenReads = 0;

  @override
  Future<String?> getAPNSToken() async {
    apnsTokenReads++;
    return apnsToken;
  }

  @override
  Future<void> subscribeToTopic(String topic) async => subscribed.add(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    unsubscribed.add(topic);
    if (topic == failingUnsubscribeTopic) throw StateError('unsubscribe failed');
    await unsubscribeGate?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('UID topic helper toggles the canonical creator topic and rejects email identifiers', () async {
    final messaging = _FakeMessaging();

    expect(await setCreatorPostsTopicForUid(messaging, 'creator-uid', subscribed: false, sourceTag: 'test'), isTrue);
    expect(await setCreatorPostsTopicForUid(messaging, 'creator-uid', subscribed: true, sourceTag: 'test'), isTrue);
    expect(
      await setCreatorPostsTopicForUid(messaging, 'ana@example.com', subscribed: true, sourceTag: 'test'),
      isFalse,
    );

    expect(messaging.unsubscribed, <String>['posts_creator-uid', 'posts_creator-uid_loc_v1', 'posts_creator-uid']);
    expect(messaging.subscribed, <String>['posts_creator-uid_loc_v1']);
  });

  test('starts all UID topic unsubscriptions without waiting for each one', () async {
    final messaging = _FakeMessaging()..unsubscribeGate = Completer<void>();

    final Future<void> unsubscribe = Future.wait(<Future<bool>>[
      for (final String uid in <String>['ana', 'lee'])
        setCreatorPostsTopicForUid(messaging, uid, subscribed: false, sourceTag: 'test'),
    ]).then((_) {});
    await Future<void>.delayed(Duration.zero);

    expect(messaging.unsubscribed, <String>['posts_ana', 'posts_lee']);

    messaging.unsubscribeGate!.complete();
    await unsubscribe;
    expect(
      messaging.unsubscribed,
      unorderedEquals(<String>['posts_ana', 'posts_ana_loc_v1', 'posts_lee', 'posts_lee_loc_v1']),
    );
  });

  test('continues creator topic unsubscriptions when one UID topic fails', () async {
    final messaging = _FakeMessaging()..failingUnsubscribeTopic = 'posts_ana';

    await Future.wait(<Future<bool>>[
      for (final String uid in <String>['ana', 'lee'])
        setCreatorPostsTopicForUid(messaging, uid, subscribed: false, sourceTag: 'test'),
    ]);

    expect(messaging.unsubscribed, <String>['posts_ana', 'posts_lee', 'posts_lee_loc_v1']);
  });

  test('missing APNS token bounds many creator unsubscriptions to one retry window', () {
    if (!(Platform.isIOS || Platform.isMacOS)) return;
    final messaging = _FakeMessaging()..apnsToken = null;
    bool completed = false;

    fakeAsync((async) {
      Future.wait(<Future<bool>>[
        for (int index = 0; index < 20; index++)
          setCreatorPostsTopicForUid(messaging, 'creator$index', subscribed: false, sourceTag: 'test'),
      ]).then((_) => completed = true);
      async.flushMicrotasks();
      expect(completed, isFalse);

      async.elapse(const Duration(milliseconds: 1800));
      async.flushMicrotasks();

      expect(completed, isTrue);
      expect(messaging.apnsTokenReads, 60);
      expect(messaging.unsubscribed, isEmpty);
    });
  });
}
