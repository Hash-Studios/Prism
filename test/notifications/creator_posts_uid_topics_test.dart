import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMessaging implements FirebaseMessaging {
  final List<String> subscribed = <String>[];
  final List<String> unsubscribed = <String>[];

  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) async => 'token';

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
  late _FakeMessaging messaging;

  setUp(() {
    messaging = _FakeMessaging();
  });

  test('topic name from a uid keeps only FCM-safe characters', () {
    expect(creatorPostsTopicFromUid('uidAna'), 'posts_uidAna');
    expect(creatorPostsTopicFromUid(' a/b+c '), 'posts_abc');
    expect(creatorPostsTopicFromUid('  '), isNull);
  });

  test('creator topics require UIDs and never infer a topic from email', () async {
    expect(
      await setCreatorPostsTopicForUid(messaging, 'ana@example.com', subscribed: true, sourceTag: 'test'),
      isFalse,
    );
    expect(await setCreatorPostsTopicForUid(messaging, 'uidAna', subscribed: true, sourceTag: 'test'), isTrue);

    expect(messaging.subscribed, <String>['posts_uidAna_loc_v1']);
  });
}
