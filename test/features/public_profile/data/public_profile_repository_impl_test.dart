import 'dart:async';
import 'dart:io';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/public_profile/data/repositories/public_profile_repository_impl.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/similar_wallpapers_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/profile_user_fixture.dart';

const Duration _profileSnapshotDiskObservationTimeout = Duration(seconds: 10);

class _WatchingClient extends FakeFirestoreClient {
  Future<List<FakeDocRow>> Function(FirestoreQuerySpec)? delayedQuery;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    final delayed = delayedQuery;
    if (delayed == null) return super.query(spec, map);
    querySpecs.add(spec);
    return (await delayed(spec)).map((row) => map(row.data, row.id)).toList();
  }

  final StreamController<List<FakeDocRow>> rows = StreamController<List<FakeDocRow>>.broadcast();
  final StreamController<int> _watchChanges = StreamController<int>.broadcast();
  final List<FirestoreQuerySpec> watchSpecs = <FirestoreQuerySpec>[];
  final StreamController<int> _cancellationChanges = StreamController<int>.broadcast();
  int cancelledWatchers = 0;
  int? failTransactionWriteNumber;
  final List<String> transactionTags = <String>[];

  /// Applies the writes of a transaction all together, or none of them, as Firestore does.
  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) async {
    transactionTags.add(sourceTag);
    final _BufferedTransaction buffer = _BufferedTransaction(failTransactionWriteNumber);
    final T value = await action(buffer);
    for (final write in buffer.writes) {
      await super.updateDoc(write.collection, write.id, write.data, sourceTag: sourceTag);
    }
    return value;
  }

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) {
    watchSpecs.add(spec);
    _watchChanges.add(watchSpecs.length);
    return Stream<List<T>>.multi((controller) {
      final StreamSubscription<List<FakeDocRow>> subscription = rows.stream.listen(
        (list) => controller.add(list.map((row) => map(row.data, row.id)).toList()),
        onError: controller.addError,
      );
      controller.onCancel = () async {
        cancelledWatchers++;
        _cancellationChanges.add(cancelledWatchers);
        await subscription.cancel();
      };
    });
  }

  Future<void> waitForWatchers(int count) async {
    while (watchSpecs.length < count) {
      await _watchChanges.stream.first;
    }
  }

  Future<void> waitForCancelledWatchers(int count) async {
    while (cancelledWatchers < count) {
      await _cancellationChanges.stream.first;
    }
  }
}

class _BufferedTransaction implements FirestoreTransaction {
  _BufferedTransaction(this.failWriteNumber);

  final int? failWriteNumber;
  final List<({String collection, String id, Map<String, dynamic> data})> writes =
      <({String collection, String id, Map<String, dynamic> data})>[];

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async => null;

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) {
    if (writes.length + 1 == failWriteNumber) throw StateError('write $failWriteNumber failed');
    writes.add((collection: collection, id: id, data: data));
  }

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data, {bool merge = false}) =>
      throw UnimplementedError();

  @override
  void deleteDoc(String collection, String id) => throw UnimplementedError();
}

FakeDocRow _user(String uid, {String name = '', String username = 'person'}) =>
    (id: uid, data: <String, dynamic>{'name': name, 'username': username, 'email': 'private@example.test'});

Future<void> _firstProfile(List<PublicProfileEntity?> emitted) async {
  while (!emitted.any((profile) => profile != null)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storeDirectory;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => storeDirectory.path,
  );
  late _WatchingClient client;
  late FakeUserBlockRepository blocks;
  late PublicProfileRepositoryImpl repo;

  setUp(() async {
    storeDirectory = await Directory.systemTemp.createTemp('prism-public-profile-test-');
    client = _WatchingClient();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    repo = PublicProfileRepositoryImpl(client, blocks);
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  tearDown(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    await client.rows.close();
    await client._watchChanges.close();
    await client._cancellationChanges.close();
    await storeDirectory.delete(recursive: true);
  });

  group('watchProfile', () {
    test('rejects email-shaped identifiers without querying private user collections', () async {
      final profile = await repo.watchProfile(' person@example.test ').first;
      expect(profile, isNull);
      expect(client.watchSpecs, isEmpty);
      expect(client.querySpecs, isEmpty);
    });

    test('queries a profile by exact UID and exposes only public projection fields', () async {
      const String uid = 'UserABC';
      client.docs['profiles'] = <String, Map<String, dynamic>>{
        uid: <String, dynamic>{
          'name': 'Ana',
          'username': 'ana',
          'bio': 'Public bio',
          'email': 'private@example.test',
          'phoneNumber': 'private phone',
          'privateField': 'secret',
          'followers': <String>['secret uid'],
          'followerCount': 7,
          'followingCount': 3,
        },
      };
      final emitted = <PublicProfileEntity?>[];
      final sub = repo.watchProfile(uid).listen(emitted.add);
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
      client.rows.add(<FakeDocRow>[(id: uid, data: client.docs['profiles']![uid]!)]);
      await _firstProfile(emitted);
      await sub.cancel();

      expect(client.watchSpecs.singleWhere((s) => s.collection == 'profiles').filters.single.value, uid);
      final profile = emitted.whereType<PublicProfileEntity>().last;
      expect((profile.id, profile.name, profile.username, profile.bio), (uid, 'Ana', 'ana', 'Public bio'));
      expect(profile.email, isEmpty);
      expect(profile.links.keys, isNot(contains('privateField')));
      expect((profile.followerCount, profile.followingCount), (7, 3));
      final List<String> relationCollections = <String>[
        ...client.watchSpecs.map((s) => s.collection),
        ...client.querySpecs.map((s) => s.collection),
      ].where((c) => c.endsWith('/followers') || c.endsWith('/following')).toList();
      expect(relationCollections, isEmpty);
    });

    test('a signed-in viewer watches one following edge doc, never the relation subcollections', () async {
      const String uid = 'UserABC';
      app_state.prismUser = profileUser(id: 'viewer-uid');
      client.docs['profiles'] = <String, Map<String, dynamic>>{
        uid: <String, dynamic>{'name': 'Ana', 'username': 'ana'},
      };
      final emitted = <PublicProfileEntity?>[];
      final sub = repo.watchProfile(uid).listen(emitted.add);
      await client.waitForWatchers(2).timeout(const Duration(seconds: 2));
      await sub.cancel();

      final edge = client.watchSpecs.singleWhere((s) => s.collection == 'profiles/viewer-uid/following');
      expect(edge.sourceTag, 'profile.following_edge');
      expect(edge.limit, 1);
      expect(client.watchSpecs.map((s) => s.collection), isNot(contains('profiles/$uid/followers')));
      expect(client.watchSpecs.map((s) => s.collection), isNot(contains('profiles/$uid/following')));
    });

    test('fetchRelationIds runs one capped, newest first query per list', () async {
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'f1', data: <String, dynamic>{}),
        (id: 'f2', data: <String, dynamic>{}),
      ];
      final result = await repo.fetchRelationIds(profileUid: 'UserABC', kind: UserRelationKind.followers);

      expect(result.data, <String>['f1', 'f2']);
      final spec = client.querySpecs.single;
      expect(spec.collection, 'profiles/UserABC/followers');
      expect(spec.sourceTag, 'public_profile.relation_ids.followers');
      expect(spec.limit, PublicProfileRepository.relationIdsLimit);
      expect((spec.orderBy.single.field, spec.orderBy.single.descending), ('createdAt', true));
    });

    test('maps cover, badges, frame, name glow and xp from the profiles document', () async {
      const String uid = 'UserABC';
      client.docs['profiles'] = <String, Map<String, dynamic>>{
        uid: <String, dynamic>{'name': 'Ana', 'username': 'ana'},
      };
      final emitted = <PublicProfileEntity?>[];
      final sub = repo.watchProfile(uid).listen(emitted.add);
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
      client.rows.add(<FakeDocRow>[
        (
          id: uid,
          data: <String, dynamic>{
            'name': 'Ana',
            'username': 'ana',
            'coverPhoto': 'https://example.test/cover.jpg',
            'badges': <String>['early_adopter', 'creator'],
            'xp': 1234,
            'cosmetics': <String, dynamic>{'frame': 'gold', 'nameGlow': 'aqua'},
            'followerCount': 7,
          },
        ),
      ]);
      await _firstProfile(emitted);
      await sub.cancel();

      final profile = emitted.whereType<PublicProfileEntity>().last;
      expect(profile.coverPhoto, 'https://example.test/cover.jpg');
      expect(profile.badges, <String>['early_adopter', 'creator']);
      expect((profile.frameId, profile.nameGlowId, profile.xp, profile.followerCount), ('gold', 'aqua', 1234, 7));
      expect(profile.premium, isFalse);
    });

    test('treats UID casing as significant', () async {
      client.docs['profiles'] = <String, Map<String, dynamic>>{
        'UserABC': <String, dynamic>{'name': 'Ana', 'username': 'ana'},
      };
      expect(await repo.watchProfile('userabc').first, isNull);
      expect(client.querySpecs, hasLength(1));
      expect(client.querySpecs.every((spec) => spec.collection == 'profiles'), isTrue);
    });

    test('unknown and incomplete profiles emit null', () async {
      expect(await repo.watchProfile('missing-uid').first, isNull);
      client.docs['profiles'] = <String, Map<String, dynamic>>{
        'incomplete-uid': <String, dynamic>{'name': 'No username'},
      };
      final emitted = <PublicProfileEntity?>[];
      final sub = repo.watchProfile('incomplete-uid').listen(emitted.add);
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
      client.rows.add(const <FakeDocRow>[
        (id: 'incomplete-uid', data: <String, dynamic>{'name': 'No username'}),
      ]);
      await pumpEventQueue();
      await sub.cancel();
      expect(emitted, <PublicProfileEntity?>[null]);
    });

    test('deleted remote projection emits null after a profile was cached', () async {
      const String uid = 'deleted-uid';
      client.docs['profiles'] = <String, Map<String, dynamic>>{
        uid: <String, dynamic>{'name': 'Ana', 'username': 'ana'},
      };
      final emitted = <String?>[];
      final sub = repo.watchProfile(uid).listen((profile) => emitted.add(profile?.name));
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
      await pumpEventQueue();
      client.rows.add(<FakeDocRow>[_user(uid, name: 'Ana', username: 'ana')]);
      while (!emitted.contains('Ana')) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      client.rows.add(const <FakeDocRow>[]);
      await pumpEventQueue();
      await sub.cancel();
      expect(emitted, containsAllInOrder(<String?>['Ana', null]));
    });

    test('profile and graph streams cancel when listener cancels', () async {
      client.docs['profiles'] = <String, Map<String, dynamic>>{
        'cancel-uid': <String, dynamic>{'name': 'Ana', 'username': 'ana'},
      };
      final sub = repo.watchProfile('cancel-uid').listen((_) {});
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
      await sub.cancel().timeout(const Duration(seconds: 2));
      await client.waitForCancelledWatchers(1).timeout(const Duration(seconds: 2));
    });
  });

  test('clearing owner removes versioned profile and wall caches and blocks late writes', () async {
    app_state.prismUser = profileUser(id: 'profile-owner');
    final snapshots = DurableJsonStore('public_profiles');
    await snapshots.write('v2::profile-owner::target-uid', <String, Object?>{'id': 'target-uid'});
    await snapshots.write('v2::profile-owner::walls:target-uid', <String, Object?>{'itemsJson': '[]'});
    await snapshots.write('v3::profile-owner::summaries:0:identity', <String, Object?>{'itemsJson': '[]'});
    await snapshots.write('v2::another-owner::target-uid', <String, Object?>{'id': 'target-uid'});
    await repo.clearForUser('profile-owner');
    expect(await snapshots.read('v2::profile-owner::target-uid'), isNull);
    expect(await snapshots.read('v2::profile-owner::walls:target-uid'), isNull);
    expect(await snapshots.read('v3::profile-owner::summaries:0:identity'), isNull);
    expect(await snapshots.read('v2::another-owner::target-uid'), isNotNull);
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  test('cancelling first after a cached profile cancels the remote watchers', () async {
    const String uid = 'cached-first-cancel-uid';
    client.docs['profiles'] = <String, Map<String, dynamic>>{
      uid: <String, dynamic>{'name': 'Cached profile', 'username': 'cached'},
    };
    final Completer<void> receivedProfile = Completer<void>();
    final initial = repo.watchProfile(uid).listen((profile) {
      if (profile?.name == 'Cached profile' && !receivedProfile.isCompleted) receivedProfile.complete();
    });
    await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
    client.rows.add(<FakeDocRow>[_user(uid, name: 'Cached profile', username: 'cached')]);
    await receivedProfile.future.timeout(_profileSnapshotDiskObservationTimeout);
    await initial.cancel();
    await client.waitForCancelledWatchers(1).timeout(const Duration(seconds: 2));

    final first = repo.watchProfile(uid).first.timeout(const Duration(seconds: 2));
    await client.waitForWatchers(2).timeout(const Duration(seconds: 2));

    expect((await first)?.name, 'Cached profile');
    await client.waitForCancelledWatchers(2).timeout(const Duration(seconds: 2));
    client.rows.add(<FakeDocRow>[_user(uid, name: 'Changed after cancellation', username: 'cached')]);
    await pumpEventQueue();

    final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
    expect((await snapshots.read('v2::__guest::$uid'))?['name'], 'Cached profile');
  });

  test('cancelling before the first remote profile cancels the watchers and ignores later rows', () async {
    const String uid = 'cancel-before-profile-uid';
    client.docs['profiles'] = <String, Map<String, dynamic>>{
      uid: <String, dynamic>{'name': 'Ana', 'username': 'ana'},
    };
    final subscription = repo.watchProfile(uid).listen((_) {});
    await client.waitForWatchers(1).timeout(const Duration(seconds: 2));

    await subscription.cancel().timeout(const Duration(seconds: 2));
    await client.waitForCancelledWatchers(1).timeout(const Duration(seconds: 2));
    client.rows.add(<FakeDocRow>[_user(uid, name: 'After cancellation')]);
    await pumpEventQueue();

    final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
    expect(await snapshots.read('v2::__guest::$uid'), isNull);
  });

  group('follow', () {
    test('sends only the target UID to the server-owned follow action', () async {
      final calls = <(String, bool)>[];
      final followRepo = PublicProfileRepositoryImpl(
        client,
        blocks,
        setFollow: (uid, following) async {
          calls.add((uid, following));
        },
      );
      final result = await followRepo.follow(
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'them',
        targetUserEmail: 'them@x.com',
      );

      expect(result.isSuccess, isTrue);
      expect(calls, <(String, bool)>[('them', true)]);
      expect(client.writes, isEmpty);
    });

    test('reports server action failures without client-side graph writes', () async {
      final followRepo = PublicProfileRepositoryImpl(
        client,
        blocks,
        setFollow: (_, _) async => throw StateError('offline'),
      );
      final result = await followRepo.follow(
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'them',
        targetUserEmail: 'them@x.com',
      );

      expect(result.failure, isA<ServerFailure>());
      expect(client.writes, isEmpty);
    });

    test('unfollow sends only a UID and does not write graph documents from the client', () async {
      final calls = <(String, bool)>[];
      final followRepo = PublicProfileRepositoryImpl(
        client,
        blocks,
        setFollow: (uid, following) async {
          calls.add((uid, following));
        },
      );
      final result = await followRepo.unfollow(
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'them',
        targetUserEmail: 'them@x.com',
      );

      expect(result.isSuccess, isTrue);
      expect(calls, <(String, bool)>[('them', false)]);
      expect(client.writes, isEmpty);
    });
  });

  group('fetchUserSummariesPage', () {
    test('queries profile document IDs and restores safe snapshots offline', () async {
      app_state.prismUser = profileUser(id: 'summary-owner');
      const ids = <String>['uid-a', 'uid-b'];
      client.onQuery = (spec) => spec.collection == 'profiles'
          ? <FakeDocRow>[
              (id: 'uid-a', data: <String, dynamic>{'name': 'Ana', 'username': 'ana', 'email': 'private@example.test'}),
              (id: 'uid-b', data: <String, dynamic>{'name': 'Bo', 'username': 'bo'}),
            ]
          : const <FakeDocRow>[];

      final result = await repo.fetchUserSummariesPage(userIds: ids, page: 0);
      expect(result.data!.items.map((user) => user.id), ids);
      expect(result.data!.items.map((user) => user.email), <String>['', '']);
      final profileQuery = client.querySpecs.singleWhere((spec) => spec.collection == 'profiles');
      expect(profileQuery.filters.single.field, firestoreDocumentIdField);
      expect(profileQuery.filters.single.value, ids);

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restarted = PublicProfileRepositoryImpl(offlineClient, blocks);
      final restored = await restarted.fetchUserSummariesPage(userIds: ids, page: 0);
      expect(restored.isSuccess, isTrue);
      expect(restored.data!.items.map((user) => user.id), ids);
      expect(restored.data!.items.map((user) => user.email), <String>['', '']);
    });

    test('deduplicates UIDs, preserves relation order, and flags followed UIDs', () async {
      app_state.prismUser = profileUser(id: 'viewer');
      app_state.prismUser.following = <String>['uid-3'];
      const ids = <String>[' uid-1 ', 'uid-2', 'uid-3', 'uid-1', ' '];
      client.onQuery = (spec) => spec.collection == 'profiles'
          ? <FakeDocRow>[
              for (final id in (spec.filters.single.value! as List<Object?>).reversed)
                (id: id! as String, data: <String, dynamic>{'name': id, 'username': id}),
            ]
          : <FakeDocRow>[(id: 'uid-3', data: <String, dynamic>{})];

      final result = await repo.fetchUserSummariesPage(userIds: ids, page: 0);
      final page = result.data!;
      expect(page.items.map((user) => user.id), <String>['uid-1', 'uid-2', 'uid-3']);
      expect(page.items.map((user) => user.email), <String>['', '', '']);
      expect(page.items.map((user) => user.isFollowedByCurrentUser), <bool>[false, false, true]);
      expect(page.hasMore, isFalse);
      expect(client.querySpecs.singleWhere((spec) => spec.collection == 'profiles').filters.single.value, <String>[
        'uid-1',
        'uid-2',
        'uid-3',
      ]);
    });

    test('pages by unique UID and does not query an email-shaped identifier', () async {
      client.onQuery = (spec) => <FakeDocRow>[
        for (final id in spec.filters.single.value! as List<Object?>)
          if (id != 'private@example.test')
            (id: id! as String, data: <String, dynamic>{'name': 'Name', 'username': 'name'}),
      ];
      final ids = <String>[for (int index = 0; index < 21; index++) 'uid-$index', 'private@example.test'];

      final first = (await repo.fetchUserSummariesPage(userIds: ids, page: 0)).data!;
      final second = (await repo.fetchUserSummariesPage(userIds: ids, page: 1)).data!;
      expect(first.items, hasLength(20));
      expect(first.hasMore, isTrue);
      expect(second.items.map((user) => user.id), <String>['uid-20']);
      expect(second.items.every((user) => user.email.isEmpty), isTrue);
      expect(client.querySpecs.last.filters.single.value, <String>['uid-20']);
    });
  });

  group('fetchWalls', () {
    List<FakeDocRow> wallRows(String prefix, {int count = 12}) => <FakeDocRow>[
      for (int i = 0; i < count; i++) (id: '$prefix-$i', data: <String, dynamic>{'wallpaper_url': '$prefix/$i'}),
    ];

    test('an old page cannot replace a refreshed cursor or durable snapshot', () async {
      client.onQuery = (_) => wallRows('initial');
      await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      final stale = Completer<List<FakeDocRow>>();
      client.delayedQuery = (_) => stale.future;
      final oldPage = repo.fetchWalls(userId: 'creator-uid', refresh: false);
      await pumpEventQueue();
      client.delayedQuery = null;
      client.onQuery = (_) => wallRows('fresh');
      await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      stale.complete(wallRows('stale'));
      await oldPage;
      client.onQuery = (_) => wallRows('next', count: 1);
      await repo.fetchWalls(userId: 'creator-uid', refresh: false);
      expect(client.querySpecs.last.startAfterDocId, 'fresh-11');
      final offline = PublicProfileRepositoryImpl(_WatchingClient()..queryError = StateError('offline'), blocks);
      final restored = await offline.fetchWalls(userId: 'creator-uid', refresh: true);
      expect(restored.data!.items.map((w) => w.id), [...List.generate(12, (i) => 'fresh-$i'), 'next-0']);
    });

    test('overlapping refreshes discard the earlier response and an empty refresh clears the cursor', () async {
      client.onQuery = (_) => wallRows('initial');
      await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      final stale = Completer<List<FakeDocRow>>();
      client.delayedQuery = (_) => stale.future;
      final oldRefresh = repo.fetchWalls(userId: 'creator-uid', refresh: true);
      await pumpEventQueue();
      client.delayedQuery = null;
      client.onQuery = (_) => <FakeDocRow>[];
      await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      stale.complete(wallRows('stale'));
      await oldRefresh;
      await repo.fetchWalls(userId: 'creator-uid', refresh: false);
      expect(client.querySpecs.last.startAfterDocId, isNull);
    });

    test('returning to the same account cannot commit an earlier session cursor or snapshot', () async {
      app_state.prismUser = profileUser(id: 'owner');
      final stale = Completer<List<FakeDocRow>>();
      client.delayedQuery = (_) => stale.future;
      final oldRefresh = repo.fetchWalls(userId: 'creator-uid', refresh: true);
      await pumpEventQueue();
      app_state.prismUser = profileUser(id: 'other');
      CoinsService.instance.resetSession();
      app_state.prismUser = profileUser(id: 'owner');
      CoinsService.instance.resetSession();
      client.delayedQuery = null;
      client.onQuery = (_) => wallRows('fresh');
      await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      stale.complete(wallRows('stale'));
      expect((await oldRefresh).isFailure, isTrue);
      await repo.fetchWalls(userId: 'creator-uid', refresh: false);
      expect(client.querySpecs.last.startAfterDocId, 'fresh-11');
    });

    test('category, not description, reaches detail before and after durable cache restore', () async {
      client.onQuery = (_) => <FakeDocRow>[
        (
          id: 'lake',
          data: <String, dynamic>{
            'category': 'Nature',
            'desc': 'A lake at dawn',
            'wallpaper_url': 'https://example.test/lake.jpg',
          },
        ),
      ];
      final fresh = await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      expect((fresh.data!.items.single.toFeedItem() as PrismFeedItem).wallpaper.core.category, 'Nature');
      expect(fresh.data!.items.single.desc, 'A lake at dawn');
      final offline = PublicProfileRepositoryImpl(_WatchingClient()..queryError = StateError('offline'), blocks);
      final restored = await offline.fetchWalls(userId: 'creator-uid', refresh: true);
      expect((restored.data!.items.single.toFeedItem() as PrismFeedItem).wallpaper.core.category, 'Nature');
      expect(restored.data!.items.single.desc, 'A lake at dawn');
      final similarClient = FakeFirestoreClient();
      final similar = SimilarWallpapersLoader(
        firestore: () => similarClient,
        blocks: () => blocks,
        search: () => throw StateError('Prism category lookup does not use text search'),
      );
      for (final result in [fresh, restored]) {
        await similar.load(result.data!.items.single.toFeedItem());
        expect(similarClient.querySpecs.last.filters.map((f) => (f.field, f.value)), contains(('category', 'Nature')));
      }
    });

    test('legacy snapshots without category do not classify description as category', () async {
      await DurableJsonStore('public_profiles').write('v2::__guest::walls:creator-uid', <String, Object?>{
        'itemsJson': '[{"id":"old","desc":"A lake at dawn","wallpaper_url":"https://x/old"}]',
        'hasMore': false,
      });
      client.queryError = StateError('offline');
      final restored = await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      expect((restored.data!.items.single.toFeedItem() as PrismFeedItem).wallpaper.core.category, isNull);
      expect(restored.data!.items.single.desc, 'A lake at dawn');
    });

    test('hides walls of a blocked creator without querying', () async {
      blocks.blockedRows = const <BlockedUserListRow>[BlockedUserListRow(blockedUid: 'blocked-uid')];
      blocks.completeInitial(<String>{'blocked-uid'});

      final result = await repo.fetchWalls(userId: 'blocked-uid', refresh: true);

      expect(result.data!.items, isEmpty);
      expect(result.data!.hasMore, isFalse);
      expect(client.querySpecs, isEmpty);
    });

    test('a full page of twelve means there is more', () async {
      client.onQuery = (spec) => <FakeDocRow>[
        for (int i = 0; i < 12; i++) (id: 'w$i', data: <String, dynamic>{'wallpaper_url': 'u$i'}),
      ];

      final result = await repo.fetchWalls(userId: 'creator-uid', refresh: true);

      expect(result.data!.items, hasLength(12));
      expect(result.data!.hasMore, isTrue);
    });

    test('a wall keeps its Firestore document id next to its own id', () async {
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-a', data: <String, dynamic>{'id': 'WALLA', 'wallpaper_url': 'https://example.test/a.jpg'}),
        (id: 'doc-b', data: <String, dynamic>{'wallpaper_url': 'https://example.test/b.jpg'}),
      ];

      final result = await repo.fetchWalls(userId: 'creator-uid', refresh: true);

      final walls = result.data!.items.map((wall) => (wall.toFeedItem() as PrismFeedItem).wallpaper);
      expect(walls.map((wall) => (wall.id, wall.firestoreDocumentId)), <(String, String?)>[
        ('WALLA', 'doc-a'),
        ('doc-b', 'doc-b'),
      ]);
    });

    test('profile walls restore from a real durable snapshot after restart while offline', () async {
      const String owner = 'walls-restart-owner';
      app_state.prismUser = profileUser(id: owner);
      client.onQuery = (_) => <FakeDocRow>[
        (
          id: 'offline-wall',
          data: <String, dynamic>{'wallpaper_url': 'https://example.test/wall.jpg', 'email': 'creator@prism.test'},
        ),
      ];
      final first = await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      expect(first.data!.items.single.id, 'offline-wall');

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restarted = PublicProfileRepositoryImpl(offlineClient, blocks);
      final restored = await restarted.fetchWalls(userId: 'creator-uid', refresh: true);

      expect(restored.isSuccess, isTrue);
      expect(restored.data!.items.single.id, 'offline-wall');
      expect(restored.data!.items.single.wallpaperUrl, 'https://example.test/wall.jpg');
    });

    test('a wall keeps its Firestore document id after a restart restores it from the cache', () async {
      app_state.prismUser = profileUser(id: 'walls-document-id-owner');
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-a', data: <String, dynamic>{'id': 'WALLA', 'wallpaper_url': 'https://example.test/a.jpg'}),
      ];
      await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-b', data: <String, dynamic>{'wallpaper_url': 'https://example.test/b.jpg'}),
      ];
      await repo.fetchWalls(userId: 'creator-uid', refresh: false);

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restored = await PublicProfileRepositoryImpl(
        offlineClient,
        blocks,
      ).fetchWalls(userId: 'creator-uid', refresh: true);

      final walls = restored.data!.items.map((wall) => (wall.toFeedItem() as PrismFeedItem).wallpaper);
      expect(walls.map((wall) => (wall.id, wall.firestoreDocumentId)), <(String, String?)>[
        ('WALLA', 'doc-a'),
        ('doc-b', 'doc-b'),
      ]);
    });

    test('cached walls still restore offline when their document id metadata is corrupt', () async {
      app_state.prismUser = profileUser(id: 'walls-corrupt-ids-owner');
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-a', data: <String, dynamic>{'id': 'WALLA', 'wallpaper_url': 'https://example.test/a.jpg'}),
      ];
      await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
      const String key = 'v2::walls-corrupt-ids-owner::walls:creator-uid';
      await snapshots.write(key, <String, Object?>{...?await snapshots.read(key), 'documentIdsJson': '{'});

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restored = await PublicProfileRepositoryImpl(
        offlineClient,
        blocks,
      ).fetchWalls(userId: 'creator-uid', refresh: true);

      expect(restored.isSuccess, isTrue);
      final walls = restored.data!.items.map((wall) => (wall.toFeedItem() as PrismFeedItem).wallpaper);
      expect(walls.map((wall) => (wall.id, wall.firestoreDocumentId)), <(String, String?)>[('WALLA', null)]);
    });

    test('a fetched next page is kept when the cached document id metadata is corrupt', () async {
      app_state.prismUser = profileUser(id: 'walls-corrupt-append-owner');
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-a', data: <String, dynamic>{'id': 'WALLA', 'wallpaper_url': 'https://example.test/a.jpg'}),
      ];
      await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
      const String key = 'v2::walls-corrupt-append-owner::walls:creator-uid';
      await snapshots.write(key, <String, Object?>{...?await snapshots.read(key), 'documentIdsJson': '[7]'});
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-b', data: <String, dynamic>{'wallpaper_url': 'https://example.test/b.jpg'}),
      ];

      final page = await repo.fetchWalls(userId: 'creator-uid', refresh: false);

      expect(page.isSuccess, isTrue);
      expect(page.data!.items.map((wall) => wall.id), <String>['doc-b']);
      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restored = await PublicProfileRepositoryImpl(
        offlineClient,
        blocks,
      ).fetchWalls(userId: 'creator-uid', refresh: true);
      final walls = restored.data!.items.map((wall) => (wall.toFeedItem() as PrismFeedItem).wallpaper);
      expect(walls.map((wall) => (wall.id, wall.firestoreDocumentId)), <(String, String?)>[
        ('WALLA', null),
        ('doc-b', 'doc-b'),
      ]);
    });

    test('a wall keeps its Depth Effect tier on the feed item, also after a restart while offline', () async {
      const String owner = 'walls-depth-owner';
      app_state.prismUser = profileUser(id: owner);
      client.onQuery = (_) => <FakeDocRow>[
        (
          id: 'checked',
          data: <String, dynamic>{
            'wallpaper_url': 'https://example.test/a.jpg',
            'email': 'creator@prism.test',
            'depth': <String, dynamic>{'tier': 'menu', 'by': 'detector'},
          },
        ),
        (id: 'unchecked', data: <String, dynamic>{'wallpaper_url': 'https://example.test/b.jpg'}),
      ];
      final first = await repo.fetchWalls(userId: 'creator-uid', refresh: true);
      expect(first.data!.items.map((wall) => wall.depthTier), <WallDepthTier?>[WallDepthTier.menu, null]);

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restored = await PublicProfileRepositoryImpl(
        offlineClient,
        blocks,
      ).fetchWalls(userId: 'creator-uid', refresh: true);

      expect(restored.data!.items.map((wall) => wall.depthTier), <WallDepthTier?>[WallDepthTier.menu, null]);
      expect((restored.data!.items.first.toFeedItem() as PrismFeedItem).wallpaper.depthTier, WallDepthTier.menu);
    });
  });
}
