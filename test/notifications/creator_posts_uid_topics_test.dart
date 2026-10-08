import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_local_store.dart';

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

class _FakeProfiles implements PublicProfileRepository {
  final Map<String, String> uidByEmail = <String, String>{};
  final List<String> reads = <String>[];
  bool failing = false;

  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) {
    reads.add(identifier);
    if (failing) return Stream<PublicProfileEntity?>.error(StateError('offline'));
    final String? uid = uidByEmail[identifier.toLowerCase()];
    return Stream<PublicProfileEntity?>.value(
      uid == null
          ? null
          : PublicProfileEntity(
              id: uid,
              name: 'Name',
              email: identifier,
              username: '',
              profilePhoto: '',
              bio: '',
              followers: const <String>[],
              following: const <String>[],
              links: const <String, String>{},
              coverPhoto: '',
            ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SettingsLocalDataSource settings;
  late _FakeMessaging messaging;
  late _FakeProfiles profiles;

  setUp(() async {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    messaging = _FakeMessaging();
    profiles = _FakeProfiles()..uidByEmail['ana@example.com'] = 'uidAna';
    await getIt.reset();
    getIt
      ..registerSingleton<SettingsLocalDataSource>(settings)
      ..registerSingleton<PublicProfileRepository>(profiles);
  });

  tearDown(() => getIt.reset());

  test('topic name from a uid keeps only FCM-safe characters', () {
    expect(creatorPostsTopicFromUid('uidAna'), 'posts_uidAna');
    expect(creatorPostsTopicFromUid(' a/b+c '), 'posts_abc');
    expect(creatorPostsTopicFromUid('  '), isNull);
  });

  test('following joins the legacy topic and posts_<uid> using a uid the caller knows', () async {
    await setCreatorPostsTopics(
      messaging,
      <String>['Ana@Example.com'],
      subscribed: true,
      sourceTag: 'test',
      knownUids: <String, String>{'ana@example.com': 'uidAna'},
    );

    expect(messaging.subscribed, unorderedEquals(<String>['Ana_posts', 'posts_uidAna']));
    expect(profiles.reads, isEmpty);
  });

  test('without a known uid the profile is read once and the uid is cached', () async {
    await setCreatorPostsTopics(messaging, <String>['ana@example.com'], subscribed: true, sourceTag: 'test');
    expect(messaging.subscribed, unorderedEquals(<String>['ana_posts', 'posts_uidAna']));
    expect(profiles.reads, <String>['ana@example.com']);

    await setCreatorPostsTopics(messaging, <String>['ana@example.com'], subscribed: false, sourceTag: 'test');
    expect(messaging.unsubscribed, unorderedEquals(<String>['ana_posts', 'posts_uidAna']));
    expect(profiles.reads, hasLength(1));
  });

  test('a creator without a profile keeps only the legacy topic', () async {
    await setCreatorPostsTopics(messaging, <String>['ghost@example.com'], subscribed: true, sourceTag: 'test');

    expect(messaging.subscribed, <String>['ghost_posts']);
  });

  test('a failed profile read does not block the legacy topic', () async {
    profiles.failing = true;

    await setCreatorPostsTopics(messaging, <String>['ana@example.com'], subscribed: true, sourceTag: 'test');

    expect(messaging.subscribed, <String>['ana_posts']);
  });

  test('sync is retried next launch when a uid read failed, and done once reads work', () async {
    Future<void> sync() => syncPushTopics(
      messaging,
      settings,
      userId: 'me',
      email: 'me@example.com',
      premium: false,
      following: const <String>['ana@example.com'],
    );

    profiles.failing = true;
    await sync();
    messaging.subscribed.clear();

    profiles.failing = false;
    await sync();
    expect(messaging.subscribed, containsAll(<String>['ana_posts', 'posts_uidAna']));

    messaging.subscribed.clear();
    await sync();
    expect(messaging.subscribed, isEmpty);
  });
}
