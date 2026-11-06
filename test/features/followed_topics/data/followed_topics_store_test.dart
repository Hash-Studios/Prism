import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/firestore/firestore_client.dart';
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
  Completer<void>? holdU1Session;
  Completer<void>? releaseU1Session;
  Completer<void>? unfollowStarted;
  Completer<void>? releaseUnfollow;
  bool failUnfollow = false;
  final List<String> operations = <String>[];
  String? holdMutationTag;
  Completer<void>? mutationStarted;
  Completer<void>? releaseMutation;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    operations.add('$sourceTag:$collection');
    if (collection == 'usersv2/u1/private' && holdU1Session != null) {
      holdU1Session!.complete();
      holdU1Session = null;
      await releaseU1Session!.future;
    }
    return super.getById<T>(collection, id, map, sourceTag: sourceTag, preferCacheFirst: preferCacheFirst);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) async {
    operations.add('$sourceTag:start');
    if (sourceTag == holdMutationTag) {
      mutationStarted!.complete();
      await releaseMutation!.future;
    }
    if (sourceTag == 'followed_topics.unfollow' && unfollowStarted != null) {
      final bool shouldFail = failUnfollow;
      if (!unfollowStarted!.isCompleted) unfollowStarted!.complete();
      await releaseUnfollow!.future;
      if (shouldFail) throw StateError('offline');
    }
    final T result = await action(_TestTransaction(this));
    operations.add('$sourceTag:end');
    return result;
  }

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

class _TestTransaction implements FirestoreTransaction {
  _TestTransaction(this.firestore);

  final _FailingWritesFirestore firestore;

  Map<String, dynamic>? _data(String collection, String id) => firestore.docs[collection]?[id];

  void _merge(String collection, String id, Map<String, dynamic> data) {
    if (firestore.failWrites) throw StateError('offline');
    firestore.writes.add((op: 'set', collection: collection, id: id, data: data));
    final Map<String, Map<String, dynamic>> docs = firestore.docs.putIfAbsent(
      collection,
      () => <String, Map<String, dynamic>>{},
    );
    docs[id] = <String, dynamic>{...?docs[id], ...data};
  }

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async => _data(collection, id);

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data, {bool merge = false}) =>
      _merge(collection, id, data);

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) => _merge(collection, id, data);

  @override
  void deleteDoc(String collection, String id) => firestore.docs[collection]?.remove(id);
}

class _FailingSeenLocalStore extends InMemoryLocalStore {
  @override
  Future<void> set(String key, Object? value) async {
    if (key.startsWith('settings.followed_topics.seen.')) throw StateError('local storage unavailable');
    await super.set(key, value);
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

  test('a local seen-marker write failure does not block the server follow', () async {
    final SettingsLocalDataSource failingSettings = SettingsLocalDataSource(_FailingSeenLocalStore());
    final FollowedTopicsStore store = FollowedTopicsStore(failingSettings, firestore);

    expect(await store.follow(FollowedTopic.category('Pastel')!), TopicFollowResult.done);
    expect(firestore.writes, hasLength(1));
  });

  test('unfollow removes only its topic and preserves offset against another-device follows', () async {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['category:Pastel'],
        'followedTopicsOffset': 0,
      },
    };
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    firestore.docs['usersv2/u1/private']!['session']!['followedTopics'] = <String>['category:Pastel', 'mood:dreamy'];

    final bool saved = await store.unfollow(FollowedTopic.category('Pastel')!);

    expect(saved, isTrue);
    expect(store.topics, isEmpty);
    final Map<String, dynamic> session = firestore.docs['usersv2/u1/private']!['session']!;
    expect(session['followedTopicsOffset'], 0);
    expect(firestore.writes.last.data, isNot(contains('followedTopicsOffset')));
    expect(session['followedTopics'], isA<FieldValue>());
  });

  test('unfollow deletes offset when another device removed the other topic first', () async {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['category:Pastel', 'mood:dreamy'],
        'followedTopicsOffset': 0,
      },
    };
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    firestore.docs['usersv2/u1/private']!['session']!['followedTopics'] = <String>['category:Pastel'];

    expect(await store.unfollow(FollowedTopic.category('Pastel')!), isTrue);

    expect(firestore.writes.last.data, contains('followedTopicsOffset'));
    expect(firestore.writes.last.data!['followedTopicsOffset'], isA<FieldValue>());
  });

  test('a failed earlier unfollow cannot restore a later successful unfollow', () async {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['category:Pastel', 'mood:dreamy'],
        'followedTopicsOffset': 0,
      },
    };
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    final Completer<void> started = Completer<void>();
    firestore.unfollowStarted = started;
    firestore.releaseUnfollow = Completer<void>();
    firestore.failUnfollow = true;

    final Future<bool> first = store.unfollow(FollowedTopic.category('Pastel')!);
    await started.future;
    firestore.failUnfollow = false;
    final Future<bool> second = store.unfollow(FollowedTopic.mood(WallMood.dreamy));
    firestore.releaseUnfollow!.complete();

    expect(await first, isFalse);
    expect(await second, isTrue);
    expect(store.topics.map((FollowedTopic topic) => topic.key), <String>['category:Pastel']);
  });

  test('loading an empty topic list clears a stale digest offset', () async {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{'followedTopics': <String>[], 'followedTopicsOffset': 0},
    };

    await newStore().ensureLoaded();

    expect(firestore.writes, isNotEmpty);
    expect(firestore.writes.last.data!['followedTopicsOffset'], isA<FieldValue>());
  });

  test('a queued follow cannot recreate state after same-account sign-out cleanup', () async {
    final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
    final FollowedTopic dreamy = FollowedTopic.mood(WallMood.dreamy);
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>[pastel.key],
        'followedTopicsOffset': 0,
      },
    };
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    firestore.unfollowStarted = Completer<void>();
    firestore.releaseUnfollow = Completer<void>();
    final Future<bool> first = store.unfollow(pastel);
    await firestore.unfollowStarted!.future;
    final Future<TopicFollowResult> queued = store.follow(dreamy);

    await store.clearLocalSeenForUser('u1');
    final int writesAfterCleanup = firestore.writes.length;
    firestore.releaseUnfollow!.complete();
    expect(await first, isFalse);

    expect(await queued, TopicFollowResult.failed);
    expect(settings.get<int?>('followed_topics.seen.u1.${dreamy.key}'), isNull);
    expect(store.topics, isEmpty);
    expect(firestore.writes.length, writesAfterCleanup);
  });

  test('a failed old mutation cannot roll back a fresh load after same-account cleanup', () async {
    final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
    final FollowedTopic dreamy = FollowedTopic.mood(WallMood.dreamy);
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>[pastel.key],
        'followedTopicsOffset': 0,
      },
    };
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    firestore.unfollowStarted = Completer<void>();
    firestore.releaseUnfollow = Completer<void>();
    firestore.failUnfollow = true;
    final Future<bool> oldMutation = store.unfollow(pastel);
    await firestore.unfollowStarted!.future;

    await store.clearLocalSeenForUser('u1');
    firestore.docs['usersv2/u1/private']!['session']!['followedTopics'] = <String>[dreamy.key];
    await store.ensureLoaded();
    firestore.releaseUnfollow!.complete();

    expect(await oldMutation, isFalse);
    expect(store.topics, <FollowedTopic>[dreamy]);
  });

  test('a queued refresh cannot recreate state after same-account sign-out cleanup', () async {
    final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>[pastel.key],
        'followedTopicsOffset': 0,
      },
    };
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    firestore.unfollowStarted = Completer<void>();
    firestore.releaseUnfollow = Completer<void>();
    final Future<bool> unfollowing = store.unfollow(pastel);
    await firestore.unfollowStarted!.future;
    final Future<void> refreshing = store.refresh();

    await store.clearLocalSeenForUser('u1');
    final int writesAfterCleanup = firestore.writes.length;
    firestore.releaseUnfollow!.complete();
    expect(await unfollowing, isFalse);
    await refreshing;

    expect(settings.get<int?>('followed_topics.seen.u1.${pastel.key}'), isNull);
    expect(store.topics, isEmpty);
    expect(firestore.writes.length, writesAfterCleanup);
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

  test('refresh reads the list and the news again: another device follow and a newer wall show up', () async {
    final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
    final FollowedTopic dreamy = FollowedTopic.mood(WallMood.dreamy);
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
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    expect(store.hasNew(pastel), isFalse);

    firestore.docs['usersv2/u1/private']!['session'] = <String, dynamic>{
      'followedTopics': <String>['category:Pastel', 'mood:dreamy'],
    };
    firestore.docs['topicNews']!['current'] = <String, dynamic>{
      'latest': <String, int>{'category:Pastel': 3000},
    };
    await store.ensureLoaded();
    expect(store.topics, <FollowedTopic>[pastel], reason: 'ensureLoaded does not read again');

    await store.refresh();

    expect(store.topics, <FollowedTopic>[pastel, dreamy]);
    expect(store.hasNew(pastel), isTrue);
  });

  for (final bool following in <bool>[true, false]) {
    final String action = following ? 'follow' : 'unfollow';
    test('refresh waits for an in-flight $action to save before reading', () async {
      final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
      firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
        'session': <String, dynamic>{
          'followedTopics': <String>[if (!following) pastel.key],
          if (!following) 'followedTopicsOffset': 0,
        },
      };
      final FollowedTopicsStore store = newStore();
      await store.ensureLoaded();
      firestore.operations.clear();
      firestore.holdMutationTag = 'followed_topics.$action';
      firestore.mutationStarted = Completer<void>();
      firestore.releaseMutation = Completer<void>();
      final Future<Object> mutation = following ? store.follow(pastel) : store.unfollow(pastel);
      await firestore.mutationStarted!.future;
      final Future<void> refreshing = store.refresh();
      await pumpEventQueue();
      final List<String> operationsWhilePending = List<String>.of(firestore.operations);
      firestore.releaseMutation!.complete();

      expect(await mutation, following ? TopicFollowResult.done : true);
      await refreshing.timeout(const Duration(seconds: 2));
      expect(operationsWhilePending, <String>['followed_topics.$action:start']);
      expect(firestore.operations.take(4), <String>[
        'followed_topics.$action:start',
        'followed_topics.$action:end',
        'followed_topics.load:usersv2/u1/private',
        'followed_topics.news:topicNews',
      ]);
    });
  }

  for (final bool refreshFirst in <bool>[true, false]) {
    test(
      'pending load with ${refreshFirst ? 'refresh then follow' : 'follow then refresh'} completes without deadlock',
      () async {
        final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
        firestore.holdU1Session = Completer<void>();
        final Completer<void> started = firestore.holdU1Session!;
        firestore.releaseU1Session = Completer<void>();
        final FollowedTopicsStore store = newStore();
        final Future<void> loading = store.ensureLoaded();
        await started.future;
        final Future<void>? firstRefresh = refreshFirst ? store.refresh() : null;
        final Future<TopicFollowResult> following = store.follow(pastel);
        final Future<void> refreshing = firstRefresh ?? store.refresh();
        await pumpEventQueue();
        expect(firestore.operations, <String>['followed_topics.load:usersv2/u1/private']);
        firestore.releaseU1Session!.complete();

        await Future.wait<void>(<Future<void>>[
          loading,
          refreshing,
          following.then<void>((_) {}),
        ]).timeout(const Duration(seconds: 2));
        expect(await following, TopicFollowResult.done);
        expect(firestore.writes.where((write) => write.data?.containsKey('followedTopics') == true), hasLength(1));
      },
    );
  }

  for (final bool signOut in <bool>[true, false]) {
    test(
      'an active refresh cannot restore the old account after ${signOut ? 'sign-out' : 'an account switch'}',
      () async {
        final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
        final FollowedTopic dreamy = FollowedTopic.mood(WallMood.dreamy);
        firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
          'session': <String, dynamic>{
            'followedTopics': <String>[pastel.key],
            'followedTopicsOffset': 0,
          },
        };
        firestore.docs['usersv2/u2/private'] = <String, Map<String, dynamic>>{
          'session': <String, dynamic>{
            'followedTopics': <String>[dreamy.key],
            'followedTopicsOffset': 0,
          },
        };
        final FollowedTopicsStore store = newStore();
        await store.ensureLoaded();
        firestore.holdU1Session = Completer<void>();
        final Completer<void> started = firestore.holdU1Session!;
        firestore.releaseU1Session = Completer<void>();
        final Future<void> refreshing = store.refresh();
        await started.future;

        if (signOut) await store.clearLocalSeenForUser('u1');
        app_state.prismUser = signOut ? app_constants.createGuestPrismUser() : profileUser(id: 'u2');
        await store.refresh().timeout(const Duration(seconds: 2));
        firestore.releaseU1Session!.complete();
        await refreshing;

        expect(store.topics, signOut ? isEmpty : <FollowedTopic>[dreamy]);
        expect(settings.get<int?>('followed_topics.seen.u1.${pastel.key}'), signOut ? isNull : 0);
        expect(firestore.writes.where((write) => write.collection == 'usersv2/u1/private'), isEmpty);
      },
    );
  }

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

  test('new-wall seen markers are scoped to the signed-in account', () async {
    final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
    await settings.set('followed_topics.seen.u1.${pastel.key}', 150);
    await settings.set('followed_topics.seen.u2.${pastel.key}', 250);
    firestore.docs['topicNews'] = <String, Map<String, dynamic>>{
      'current': <String, dynamic>{
        'latest': <String, int>{pastel.key: 200},
      },
    };
    for (final String uid in <String>['u1', 'u2']) {
      firestore.docs['usersv2/$uid/private'] = <String, Map<String, dynamic>>{
        'session': <String, dynamic>{
          'followedTopics': <String>[pastel.key],
        },
      };
    }
    final FollowedTopicsStore store = newStore();
    await store.ensureLoaded();
    expect(store.hasNew(pastel), isTrue);

    app_state.prismUser = profileUser(id: 'u2');
    await store.ensureLoaded();

    expect(store.hasNew(pastel), isFalse);
  });

  test('a pending load cannot recreate seen markers after sign-out cleanup', () async {
    final FollowedTopic pastel = FollowedTopic.category('Pastel')!;
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>[pastel.key],
      },
    };
    final Completer<void> held = Completer<void>();
    firestore.holdU1Session = held;
    firestore.releaseU1Session = Completer<void>();
    final FollowedTopicsStore store = newStore();
    final Future<void> loading = store.ensureLoaded();
    await held.future;

    await store.clearLocalSeenForUser('u1');
    firestore.releaseU1Session!.complete();
    await loading;

    expect(settings.get<int?>('followed_topics.seen.u1.${pastel.key}'), isNull);
    expect(store.topics, isEmpty);
  });

  test('account switch during a load does not block the new account or write for the old one', () async {
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
    final Completer<void> held = Completer<void>();
    firestore.holdU1Session = held;
    firestore.releaseU1Session = Completer<void>();
    final FollowedTopicsStore store = newStore();
    final Future<void> oldLoad = store.ensureLoaded();
    await held.future;
    final Future<TopicFollowResult> oldFollow = store.follow(FollowedTopic.category('Pastel')!);

    app_state.prismUser = profileUser(id: 'u2');
    await store.ensureLoaded();
    expect(store.topics.map((FollowedTopic topic) => topic.key), <String>['mood:dreamy']);

    firestore.releaseU1Session!.complete();
    await oldLoad;
    expect(await oldFollow, TopicFollowResult.failed);
    expect(firestore.writes.where((write) => write.collection == 'usersv2/u1/private'), isEmpty);
    expect(store.topics.map((FollowedTopic topic) => topic.key), <String>['mood:dreamy']);
  });

  test('same-account cleanup allows a fresh load without waiting for the old load', () async {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['mood:dreamy'],
      },
    };
    firestore.holdU1Session = Completer<void>();
    final Completer<void> started = firestore.holdU1Session!;
    firestore.releaseU1Session = Completer<void>();
    final FollowedTopicsStore store = newStore();
    final Future<void> oldLoad = store.ensureLoaded();
    await started.future;
    await store.clearLocalSeenForUser('u1');

    try {
      await store.ensureLoaded().timeout(const Duration(seconds: 2));
      expect(store.topics, <FollowedTopic>[FollowedTopic.mood(WallMood.dreamy)]);
    } finally {
      firestore.releaseU1Session!.complete();
      await oldLoad;
    }
  });

  test('an old load completion cannot evict a newer same-account load', () async {
    firestore.holdU1Session = Completer<void>();
    final Completer<void> oldStarted = firestore.holdU1Session!;
    final Completer<void> oldRelease = Completer<void>();
    firestore.releaseU1Session = oldRelease;
    final FollowedTopicsStore store = newStore();
    final Future<void> oldLoad = store.ensureLoaded();
    await oldStarted.future;
    await store.clearLocalSeenForUser('u1');
    firestore.holdU1Session = Completer<void>();
    firestore.releaseU1Session = Completer<void>();
    final Future<void> freshLoad = store.ensureLoaded();

    oldRelease.complete();
    await oldLoad;
    try {
      expect(identical(store.ensureLoaded(), freshLoad), isTrue);
    } finally {
      firestore.releaseU1Session!.complete();
      await freshLoad;
    }
  });
}
