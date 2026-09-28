import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMessaging implements FirebaseMessaging {
  final List<String> subscribed = <String>[];
  final List<String> unsubscribed = <String>[];

  @override
  Future<String?> getAPNSToken() async => 'apns';

  @override
  Future<void> subscribeToTopic(String topic) async => subscribed.add(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) async => unsubscribed.add(topic);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the Posts switch toggles each followed creator topic that onWallApproved sends to', () async {
    final messaging = _FakeMessaging();
    const creators = <String>['ana@example.com', 'j.doe+art@example.com', '@broken'];

    await setCreatorPostsTopics(messaging, creators, subscribed: false, sourceTag: 'test');
    await setCreatorPostsTopics(messaging, creators, subscribed: true, sourceTag: 'test');

    expect(messaging.unsubscribed, <String>['ana_posts', 'j.doeart_posts']);
    expect(messaging.subscribed, messaging.unsubscribed);
  });
}
