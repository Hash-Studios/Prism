import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/followed_topics/data/followed_topics_store.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/profile_user_fixture.dart';

/// Fails every write while [failWrites] is true, so a test can break the save after the list has loaded.
class _FailingWritesFirestore extends FakeFirestoreClient {
  bool failWrites = false;

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async {
    if (failWrites) throw StateError('offline');
    await super.setDoc(collection, id, data, merge: merge, sourceTag: sourceTag);
  }
}

void main() {
  late InMemoryLocalStore localStore;
  late SettingsLocalDataSource settings;
  late _FailingWritesFirestore firestore;

  FollowedTopicsStore newStore() => FollowedTopicsStore(settings, firestore);

  setUp(() {
    localStore = InMemoryLocalStore();
    settings = SettingsLocalDataSource(localStore);
    firestore = _FailingWritesFirestore();
    app_state.prismUser = profileUser();
  });

  tearDown(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  test('a guest has no topics, and follow fails without a write', () async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final FollowedTopicsStore store = newStore();

    await store.ensureLoaded();

    expect(store.topics, isEmpty);
    expect(await store.follow(FollowedTopic.category('Pastel')!), TopicFollowResult.failed);
    expect(store.topics, isEmpty);
    expect(firestore.writes, isEmpty);
  });

  test('ensureLoaded keeps the known keys in order and drops the unknown ones', () async {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['mood:dreamy', 'category:AMOLED', 'category:Pastel'],
      },
    };
    final FollowedTopicsStore store = newStore();

    await store.ensureLoaded();

    expect(store.topics.map((FollowedTopic topic) => topic.key).toList(), <String>['mood:dreamy', 'category:Pastel']);
  });

  test('follow adds the topic and saves it to the session doc with the device offset', () async {
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();

    final TopicFollowResult result = await store.follow(FollowedTopic.category('Pastel')!);

    expect(result, TopicFollowResult.done);
    expect(store.topics.map((FollowedTopic topic) => topic.key).toList(), <String>['category:Pastel']);
    final Map<String, dynamic> session = firestore.docs['usersv2/u1/private']!['session']!;
    expect(session['followedTopics'], isA<FieldValue>());
    expect(session['followedTopicsOffset'], isA<int>());
  });

  test('a 21st topic returns limit and writes nothing new', () async {
    final List<String> twenty = <String>[for (final String name in prismClassifierCategories) 'category:$name'];
    expect(twenty, hasLength(FollowedTopic.maxFollowed));
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{'followedTopics': twenty},
    };
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    final int writesBefore = firestore.writes.length;

    final TopicFollowResult result = await store.follow(FollowedTopic.mood(WallMood.dreamy));

    expect(result, TopicFollowResult.limit);
    expect(store.topics, hasLength(FollowedTopic.maxFollowed));
    expect(store.isFollowed(FollowedTopic.mood(WallMood.dreamy)), isFalse);
    expect(firestore.writes.length, writesBefore);
  });

  test('a write that throws returns failed and the topic is not kept', () async {
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    firestore.failWrites = true;

    final TopicFollowResult result = await store.follow(FollowedTopic.category('Pastel')!);

    expect(result, TopicFollowResult.failed);
    expect(store.topics, isEmpty);
  });

  test('unfollow of the last topic saves the offset as a delete and leaves the list empty', () async {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['category:Pastel'],
      },
    };
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();

    final bool saved = await store.unfollow(FollowedTopic.category('Pastel')!);

    expect(saved, isTrue);
    expect(store.topics, isEmpty);
    final Map<String, dynamic> session = firestore.docs['usersv2/u1/private']!['session']!;
    expect(session['followedTopicsOffset'], isA<FieldValue>());
    expect(session['followedTopics'], isA<FieldValue>());
  });

  test('a topic followed on another device shows no dot until a newer wall lands, and markSeen clears it', () async {
    final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
    firestore.docs['topicNews'] = <String, Map<String, dynamic>>{
      'current': <String, dynamic>{
        'latest': <String, int>{'category:Pastel': 2000},
      },
    };
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['category:Pastel'],
      },
    };
    final FollowedTopicsStore first = newStore();
    await first.ensureLoaded();

    expect(first.hasNew(pastel), isFalse);

    firestore.docs['topicNews']!['current'] = <String, dynamic>{
      'latest': <String, int>{'category:Pastel': 3000},
    };
    final FollowedTopicsStore later = newStore();
    await later.ensureLoaded();

    expect(later.hasNew(pastel), isTrue);

    await later.markSeen(pastel);

    expect(later.hasNew(pastel), isFalse);
  });

  test('after the signed-in user changes, ensureLoaded reads the new user list', () async {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['category:Pastel'],
      },
    };
    firestore.docs['usersv2/u2/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['mood:dreamy'],
      },
    };
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    expect(store.topics.map((FollowedTopic topic) => topic.key).toList(), <String>['category:Pastel']);

    app_state.prismUser = profileUser(id: 'u2');
    await store.ensureLoaded();

    expect(store.topics.map((FollowedTopic topic) => topic.key).toList(), <String>['mood:dreamy']);
  });
}
