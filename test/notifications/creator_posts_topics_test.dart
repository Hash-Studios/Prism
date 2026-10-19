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
  test('the Posts switch toggles each followed creator topic that onWallApproved sends to', () async {
    final messaging = _FakeMessaging();
    const creators = <String>['ana@example.com', 'j.doe+art@example.com', '@broken'];

    await setCreatorPostsTopics(messaging, creators, subscribed: false, sourceTag: 'test');
    await setCreatorPostsTopics(messaging, creators, subscribed: true, sourceTag: 'test');

    expect(
      messaging.unsubscribed,
      containsAll(<String>['ana_posts', 'ana_posts_loc_v1', 'j.doeart_posts', 'j.doeart_posts_loc_v1']),
    );
    expect(messaging.subscribed, <String>['ana_posts_loc_v1', 'j.doeart_posts_loc_v1']);
  });

  test('starts all creator topic unsubscriptions without waiting for each one', () async {
    final messaging = _FakeMessaging()..unsubscribeGate = Completer<void>();

    final Future<void> unsubscribe = setCreatorPostsTopics(
      messaging,
      <String>['ana@example.com', 'lee@example.com'],
      subscribed: false,
      sourceTag: 'test',
    );
    await Future<void>.delayed(Duration.zero);

    expect(messaging.unsubscribed, <String>['ana_posts', 'lee_posts']);

    messaging.unsubscribeGate!.complete();
    await unsubscribe;
    expect(
      messaging.unsubscribed,
      unorderedEquals(<String>['ana_posts', 'ana_posts_loc_v1', 'lee_posts', 'lee_posts_loc_v1']),
    );
  });

  test('continues creator topic unsubscriptions when one topic fails', () async {
    final messaging = _FakeMessaging()..failingUnsubscribeTopic = 'ana_posts';

    await setCreatorPostsTopics(
      messaging,
      <String>['ana@example.com', 'lee@example.com'],
      subscribed: false,
      sourceTag: 'test',
    );

    expect(messaging.unsubscribed, <String>['ana_posts', 'lee_posts', 'lee_posts_loc_v1']);
  });

  test('missing APNS token bounds many creator unsubscriptions to one retry window', () {
    if (!(Platform.isIOS || Platform.isMacOS)) return;
    final messaging = _FakeMessaging()..apnsToken = null;
    bool completed = false;

    fakeAsync((async) {
      setCreatorPostsTopics(
        messaging,
        List<String>.generate(20, (int index) => 'creator$index@example.com'),
        subscribed: false,
        sourceTag: 'test',
      ).then((_) => completed = true);
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
