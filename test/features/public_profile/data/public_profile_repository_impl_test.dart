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

FakeDocRow _user(String email, {String name = ''}) =>
    (id: 'id_$email', data: <String, dynamic>{'email': email, 'name': name, 'username': email.split('@').first});

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
    test('looks a user up by email or by username', () async {
      final first = repo.watchProfile(' me@x.com ').listen((_) {});
      final second = repo.watchProfile('kevin').listen((_) {});
      await client.waitForWatchers(2).timeout(const Duration(seconds: 2));

      final fields = client.watchSpecs.map((spec) => spec.filters.single).toList();
      expect((fields[0].field, fields[0].value), ('email', 'me@x.com'));
      expect((fields[1].field, fields[1].value), ('username', 'kevin'));
      await first.cancel();
      await second.cancel();
    });

    test('emits the profile, or null when nobody matches', () async {
      final emitted = <String?>[];
      final Completer<void> bothSnapshotsMapped = Completer<void>();
      final sub = repo.watchProfile('a@x.com').listen((profile) {
        emitted.add(profile?.name);
        if (emitted.length == 2) bothSnapshotsMapped.complete();
      });
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));

      client.rows.add(<FakeDocRow>[_user('a@x.com', name: 'Ana')]);
      client.rows.add(const <FakeDocRow>[]);
      await bothSnapshotsMapped.future.timeout(_profileSnapshotDiskObservationTimeout);
      await sub.cancel();

      expect(emitted, <String?>['Ana', null]);
    });

    test('uses the document id, which follow and block calls need', () async {
      final Completer<String> receivedId = Completer<String>();
      final sub = repo.watchProfile('a@x.com').listen((profile) => receivedId.complete(profile!.id));
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));

      client.rows.add(<FakeDocRow>[_user('a@x.com')]);
      final String profileId = await receivedId.future.timeout(_profileSnapshotDiskObservationTimeout);
      await sub.cancel();

      expect(profileId, 'id_a@x.com');
    });

    test('maps server badge objects and accepts profiles from before badges existed', () async {
      final badgeIds = <List<String>>[];
      final Completer<void> bothSnapshotsMapped = Completer<void>();
      final sub = repo.watchProfile('a@x.com').listen((profile) {
        badgeIds.add(profile!.badges);
        if (badgeIds.length == 2) bothSnapshotsMapped.complete();
      });
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
      client.rows.add(<FakeDocRow>[
        (
          id: 'u1',
          data: <String, dynamic>{
            'badges': <Object?>[
              <String, Object?>{'id': 'creator', 'name': 'Creator', 'awardedAt': '2026-01-01'},
              <String, Object?>{'id': 'future_badge'},
              <String, Object?>{'name': 'Malformed'},
              null,
            ],
          },
        ),
      ]);
      client.rows.add(<FakeDocRow>[_user('a@x.com')]);
      await bothSnapshotsMapped.future.timeout(_profileSnapshotDiskObservationTimeout);
      await sub.cancel();

      expect(badgeIds, <List<String>>[
        <String>['creator', 'future_badge'],
        <String>[],
      ]);
    });

    test('a profile larger than the snapshot limit still reaches the remote subscriber', () async {
      final String name = 'x' * (1024 * 1024);
      final Completer<int> receivedNameLength = Completer<int>();
      final subscription = repo.watchProfile('large-profile@x.com').listen((profile) {
        if (profile != null && !receivedNameLength.isCompleted) {
          receivedNameLength.complete(profile.name.length);
        }
      });
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
      client.rows.add(<FakeDocRow>[
        (id: 'large-profile', data: <String, dynamic>{'email': 'large-profile@x.com', 'name': name}),
      ]);

      expect(await receivedNameLength.future.timeout(_profileSnapshotDiskObservationTimeout), name.length);
      await subscription.cancel();
    });

    test('a profile snapshot is available after restart before the next remote snapshot', () async {
      const email = 'offline-profile-snapshot@prism.test';
      final Completer<void> received = Completer<void>();
      final subscription = repo.watchProfile(email).listen((profile) {
        if (profile?.name == 'Saved profile' && !received.isCompleted) received.complete();
      });
      await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
      client.rows.add(<FakeDocRow>[_user(email, name: 'Saved profile')]);
      await received.future.timeout(_profileSnapshotDiskObservationTimeout);
      await subscription.cancel();

      final restarted = PublicProfileRepositoryImpl(_WatchingClient(), blocks);
      final cached = await restarted.watchProfile(email).first.timeout(_profileSnapshotDiskObservationTimeout);

      expect(cached?.name, 'Saved profile');
    });
  });

  test('a profile stream write that arrives after owner cleanup cannot restore the snapshot', () async {
    app_state.prismUser = profileUser(id: 'profile-owner');
    const String email = 'late-profile@prism.test';
    final Completer<void> lateProfileObserved = Completer<void>();
    final subscription = repo.watchProfile(email).listen((profile) {
      if (profile?.name == 'Late profile' && !lateProfileObserved.isCompleted) {
        lateProfileObserved.complete();
      }
    });
    await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
    await repo.clearForUser('profile-owner');

    client.rows.add(<FakeDocRow>[_user(email, name: 'Late profile')]);
    await lateProfileObserved.future.timeout(_profileSnapshotDiskObservationTimeout);
    await subscription.cancel();

    final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
    expect(await snapshots.read('profile-owner::${email.toLowerCase()}'), isNull);
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  test('cancelling first after a cached profile cancels the remote watcher', () async {
    const String email = 'cached-first-cancel@prism.test';
    final Completer<void> receivedProfile = Completer<void>();
    final initial = repo.watchProfile(email).listen((profile) {
      if (profile?.name == 'Cached profile' && !receivedProfile.isCompleted) receivedProfile.complete();
    });
    await client.waitForWatchers(1).timeout(const Duration(seconds: 2));
    client.rows.add(<FakeDocRow>[_user(email, name: 'Cached profile')]);
    await receivedProfile.future.timeout(_profileSnapshotDiskObservationTimeout);
    await initial.cancel();
    await client.waitForCancelledWatchers(1).timeout(const Duration(seconds: 2));

    final first = repo.watchProfile(email).first.timeout(const Duration(seconds: 2));
    await client.waitForWatchers(2).timeout(const Duration(seconds: 2));

    expect((await first)?.name, 'Cached profile');
    await client.waitForCancelledWatchers(2).timeout(const Duration(seconds: 2));
    client.rows.add(<FakeDocRow>[_user(email, name: 'Changed after cancellation')]);

    final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
    expect((await snapshots.read('__guest::${email.toLowerCase()}'))?['name'], 'Cached profile');
  });

  test('cancelling before the first remote profile cancels the watcher and ignores later rows', () async {
    const String email = 'cancel-before-profile@prism.test';
    final subscription = repo.watchProfile(email).listen((_) {});
    await client.waitForWatchers(1).timeout(const Duration(seconds: 2));

    await subscription.cancel().timeout(const Duration(seconds: 2));
    await client.waitForCancelledWatchers(1).timeout(const Duration(seconds: 2));
    client.rows.add(<FakeDocRow>[_user(email, name: 'After cancellation')]);

    final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
    expect(await snapshots.read('__guest::${email.toLowerCase()}'), isNull);
  });

  group('follow', () {
    test('adds each side to the other list', () async {
      final result = await repo.follow(
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'them',
        targetUserEmail: 'them@x.com',
      );

      expect(result.isSuccess, isTrue);
      expect(client.writes.map((w) => (w.collection, w.id, w.data!.keys.single)), <(String, String, String)>[
        ('usersv2', 'me', 'following'),
        ('usersv2', 'them', 'followers'),
      ]);
      expect(client.transactionTags, <String>['public_profile.follow']);
    });

    test('commits neither side when the second write fails', () async {
      client.failTransactionWriteNumber = 2;

      final result = await repo.follow(
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'them',
        targetUserEmail: 'them@x.com',
      );

      expect(result.failure, isA<ServerFailure>());
      expect(client.writes, isEmpty);
    });

    test('unfollow also commits neither side when the second write fails', () async {
      client.failTransactionWriteNumber = 2;

      final result = await repo.unfollow(
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'them',
        targetUserEmail: 'them@x.com',
      );

      expect(result.failure, isA<ServerFailure>());
      expect(client.writes, isEmpty);
    });

    test('unfollow touches the same fields and reports write errors as a failure', () async {
      await repo.unfollow(
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'them',
        targetUserEmail: 'them@x.com',
      );
      expect(client.writes.map((w) => w.data!.keys.single), <String>['following', 'followers']);

      client.failTransactionWriteNumber = 1;
      final failed = await repo.unfollow(
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'them',
        targetUserEmail: 'them@x.com',
      );
      expect(failed.failure, isA<ServerFailure>());
    });
  });

  group('fetchUserSummariesPage', () {
    test('real durable JSON summary snapshots restore after repository restart while offline', () async {
      const String owner = 'summary-restart-owner';
      app_state.prismUser = profileUser(id: owner);
      client.onQuery = (_) => <FakeDocRow>[_user('offline-summary@prism.test', name: 'Cached Name')];
      final first = await repo.fetchUserSummariesPage(allEmails: <String>['offline-summary@prism.test'], page: 0);
      expect(first.data!.items.single.name, 'Cached Name');

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restarted = PublicProfileRepositoryImpl(offlineClient, blocks);
      final restored = await restarted.fetchUserSummariesPage(
        allEmails: <String>['offline-summary@prism.test'],
        page: 0,
      );

      expect(restored.isSuccess, isTrue);
      expect(restored.data!.items.single.name, 'Cached Name');
    });

    test('reads one page in chunks of ten, in the order given, and flags followed users', () async {
      app_state.prismUser = profileUser();
      app_state.prismUser.following = <String>['u3@x.com'];
      final emails = <String>[for (int i = 0; i < 25; i++) 'u$i@x.com'];
      client.onQuery = (spec) {
        final wanted = spec.filters.single.value! as List<Object?>;
        // Answer in reverse so the ordering has to come from the repository.
        return <FakeDocRow>[for (final email in wanted.reversed) _user(email! as String)];
      };

      final result = await repo.fetchUserSummariesPage(allEmails: emails, page: 0);

      final page = result.data!;
      expect(page.items.map((u) => u.email), emails.take(20));
      expect(page.hasMore, isTrue);
      expect(client.querySpecs, hasLength(2));
      expect(page.items[3].isFollowedByCurrentUser, isTrue);
      expect(page.items[4].isFollowedByCurrentUser, isFalse);
    });

    test('the last page has no more and a page past the end is empty', () async {
      final emails = <String>[for (int i = 0; i < 25; i++) 'u$i@x.com'];
      client.onQuery = (spec) => <FakeDocRow>[
        for (final email in spec.filters.single.value! as List<Object?>) _user(email! as String),
      ];

      final last = (await repo.fetchUserSummariesPage(allEmails: emails, page: 1)).data!;
      final beyond = (await repo.fetchUserSummariesPage(allEmails: emails, page: 2)).data!;

      expect(last.items, hasLength(5));
      expect(last.hasMore, isFalse);
      expect(beyond.items, isEmpty);
    });

    test('blank and repeated emails are dropped before querying', () async {
      client.onQuery = (spec) => <FakeDocRow>[_user('a@x.com')];

      final result = await repo.fetchUserSummariesPage(allEmails: <String>[' A@x.com', 'a@x.com', ' '], page: 0);

      expect(result.data!.items.map((u) => u.email), <String>['a@x.com']);
      expect(client.querySpecs.single.filters.single.value, <String>['A@x.com', 'a@x.com']);
    });

    // Firestore whereIn compares strings exactly, so the fake must not fold case. Without an
    // orderBy, Firestore returns documents by document ID, then applies the limit.
    List<FakeDocRow> exactEmailMatch(FirestoreQuerySpec spec, List<FakeDocRow> stored) {
      final wanted = spec.filters.single.value! as List<Object?>;
      final rows = stored.where((row) => wanted.contains(row.data['email'])).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      return rows.take(spec.limit ?? rows.length).toList();
    }

    FakeDocRow storedAs(String id, String email, String name) =>
        (id: id, data: <String, dynamic>{'email': email, 'name': name, 'username': name});

    test('a user stored with a mixed-case email is found through the relation spelling (#541)', () async {
      final stored = <FakeDocRow>[_user('Alice@Example.com', name: 'Alice'), _user('bob@example.com', name: 'Bob')];
      client.onQuery = (spec) => exactEmailMatch(spec, stored);

      final result = await repo.fetchUserSummariesPage(
        allEmails: <String>['Alice@Example.com', 'bob@example.com'],
        page: 0,
      );

      expect(result.data!.items.map((u) => u.name), <String>['Alice', 'Bob']);
      expect(result.data!.items.first.email, 'Alice@Example.com');
      expect(result.data!.hasMore, isFalse);
    });

    test('a mixed-case relation entry still finds a user stored in lowercase', () async {
      final stored = <FakeDocRow>[_user('carol@example.com', name: 'Carol')];
      client.onQuery = (spec) => exactEmailMatch(spec, stored);

      final result = await repo.fetchUserSummariesPage(allEmails: <String>['Carol@Example.com'], page: 0);

      expect(result.data!.items.map((u) => u.name), <String>['Carol']);
    });

    test('two spellings of one address give one summary and one pagination slot', () async {
      final stored = <FakeDocRow>[_user('Dana@Example.com', name: 'Dana')];
      client.onQuery = (spec) => exactEmailMatch(spec, stored);
      final emails = <String>['Dana@Example.com', 'dana@example.com', for (int i = 0; i < 19; i++) 'u$i@x.com'];

      final first = (await repo.fetchUserSummariesPage(allEmails: emails, page: 0)).data!;
      final second = (await repo.fetchUserSummariesPage(allEmails: emails, page: 1)).data!;

      expect(first.items.map((u) => u.name), <String>['Dana']);
      expect(first.hasMore, isFalse);
      expect(second.items, isEmpty);
    });

    test('the relation spelling wins over a lowercase duplicate that Firestore returns first', () async {
      final stored = <FakeDocRow>[
        storedAs('a_lower', 'alice@example.com', 'lowercase account'),
        storedAs('b_exact', 'Alice@Example.com', 'exact account'),
      ];
      client.onQuery = (spec) => exactEmailMatch(spec, stored);

      final exact = await repo.fetchUserSummariesPage(allEmails: <String>['Alice@Example.com'], page: 0);
      final lower = await repo.fetchUserSummariesPage(allEmails: <String>['alice@example.com'], page: 0);

      expect(exact.data!.items.map((u) => u.name), <String>['exact account']);
      expect(lower.data!.items.map((u) => u.name), <String>['lowercase account']);
      // A lowercase relation does not invent a mixed-case variant to query.
      expect(client.querySpecs.last.filters.single.value, <String>['alice@example.com']);
    });

    test('the first relation spelling wins when the list holds two spellings', () async {
      final stored = <FakeDocRow>[
        storedAs('a_lower', 'alice@example.com', 'lowercase account'),
        storedAs('b_exact', 'Alice@Example.com', 'exact account'),
      ];
      client.onQuery = (spec) => exactEmailMatch(spec, stored);

      final result = await repo.fetchUserSummariesPage(
        allEmails: <String>['Alice@Example.com', 'alice@example.com'],
        page: 0,
      );

      expect(result.data!.items.map((u) => u.name), <String>['exact account']);
    });

    test('a mixed-case duplicate on the second page across a ten-value chunk keeps the relation spelling', () async {
      final stored = <FakeDocRow>[
        for (int i = 0; i < 29; i++) storedAs('id_u$i', 'u$i@x.com', 'u$i'),
        storedAs('a_lower', 'eve@example.com', 'lowercase account'),
        storedAs('b_exact', 'Eve@Example.com', 'exact account'),
      ];
      client.onQuery = (spec) => exactEmailMatch(spec, stored);
      // Page 1 holds u20..u28 then Eve, so her two spellings are values 10 and 11 of the lookup.
      final emails = <String>[for (int i = 0; i < 29; i++) 'u$i@x.com', 'Eve@Example.com'];

      final second = (await repo.fetchUserSummariesPage(allEmails: emails, page: 1)).data!;

      expect(second.items.map((u) => u.name), <String>[for (int i = 20; i < 29; i++) 'u$i', 'exact account']);
      expect(second.hasMore, isFalse);
      expect(client.querySpecs.map((s) => s.filters.single.value), <Object?>[
        <String>[for (int i = 20; i < 29; i++) 'u$i@x.com', 'Eve@Example.com'],
        <String>['eve@example.com'],
      ]);
    });

    test('mixed-case lookups stay within ten values per whereIn query', () async {
      final emails = <String>[for (int i = 0; i < 20; i++) 'User$i@X.com'];
      client.onQuery = (_) => <FakeDocRow>[];

      await repo.fetchUserSummariesPage(allEmails: emails, page: 0);

      final queried = <Object?>[for (final spec in client.querySpecs) ...(spec.filters.single.value! as List<Object?>)];
      expect(client.querySpecs.every((s) => (s.filters.single.value! as List<Object?>).length <= 10), isTrue);
      expect(queried.toSet(), <Object?>{...emails, ...emails.map((e) => e.toLowerCase())});
    });
  });

  group('fetchWalls', () {
    List<FakeDocRow> wallRows(String prefix, {int count = 12}) => <FakeDocRow>[
      for (int i = 0; i < count; i++) (id: '$prefix-$i', data: <String, dynamic>{'wallpaper_url': '$prefix/$i'}),
    ];

    test('an old page cannot replace a refreshed cursor or durable snapshot', () async {
      client.onQuery = (_) => wallRows('initial');
      await repo.fetchWalls(email: 'creator@x.com', refresh: true);
      final stale = Completer<List<FakeDocRow>>();
      client.delayedQuery = (_) => stale.future;
      final oldPage = repo.fetchWalls(email: 'creator@x.com', refresh: false);
      await pumpEventQueue();
      client.delayedQuery = null;
      client.onQuery = (_) => wallRows('fresh');
      await repo.fetchWalls(email: 'creator@x.com', refresh: true);
      stale.complete(wallRows('stale'));
      await oldPage;
      client.onQuery = (_) => wallRows('next', count: 1);
      await repo.fetchWalls(email: 'creator@x.com', refresh: false);
      expect(client.querySpecs.last.startAfterDocId, 'fresh-11');
      final offline = PublicProfileRepositoryImpl(_WatchingClient()..queryError = StateError('offline'), blocks);
      final restored = await offline.fetchWalls(email: 'creator@x.com', refresh: true);
      expect(restored.data!.items.map((w) => w.id), [...List.generate(12, (i) => 'fresh-$i'), 'next-0']);
    });

    test('overlapping refreshes discard the earlier response and an empty refresh clears the cursor', () async {
      client.onQuery = (_) => wallRows('initial');
      await repo.fetchWalls(email: 'creator@x.com', refresh: true);
      final stale = Completer<List<FakeDocRow>>();
      client.delayedQuery = (_) => stale.future;
      final oldRefresh = repo.fetchWalls(email: 'creator@x.com', refresh: true);
      await pumpEventQueue();
      client.delayedQuery = null;
      client.onQuery = (_) => <FakeDocRow>[];
      await repo.fetchWalls(email: 'creator@x.com', refresh: true);
      stale.complete(wallRows('stale'));
      await oldRefresh;
      await repo.fetchWalls(email: 'creator@x.com', refresh: false);
      expect(client.querySpecs.last.startAfterDocId, isNull);
    });

    test('returning to the same account cannot commit an earlier session cursor or snapshot', () async {
      app_state.prismUser = profileUser(id: 'owner');
      final stale = Completer<List<FakeDocRow>>();
      client.delayedQuery = (_) => stale.future;
      final oldRefresh = repo.fetchWalls(email: 'creator@x.com', refresh: true);
      await pumpEventQueue();
      app_state.prismUser = profileUser(id: 'other');
      CoinsService.instance.resetSession();
      app_state.prismUser = profileUser(id: 'owner');
      CoinsService.instance.resetSession();
      client.delayedQuery = null;
      client.onQuery = (_) => wallRows('fresh');
      await repo.fetchWalls(email: 'creator@x.com', refresh: true);
      stale.complete(wallRows('stale'));
      expect((await oldRefresh).isFailure, isTrue);
      await repo.fetchWalls(email: 'creator@x.com', refresh: false);
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
      final fresh = await repo.fetchWalls(email: 'creator@x.com', refresh: true);
      expect((fresh.data!.items.single.toFeedItem() as PrismFeedItem).wallpaper.core.category, 'Nature');
      expect(fresh.data!.items.single.desc, 'A lake at dawn');
      final offline = PublicProfileRepositoryImpl(_WatchingClient()..queryError = StateError('offline'), blocks);
      final restored = await offline.fetchWalls(email: 'creator@x.com', refresh: true);
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
      await DurableJsonStore('public_profiles').write('__guest::walls:creator@x.com', <String, Object?>{
        'itemsJson': '[{"id":"old","desc":"A lake at dawn","wallpaper_url":"https://x/old"}]',
        'hasMore': false,
      });
      client.queryError = StateError('offline');
      final restored = await repo.fetchWalls(email: 'creator@x.com', refresh: true);
      expect((restored.data!.items.single.toFeedItem() as PrismFeedItem).wallpaper.core.category, isNull);
      expect(restored.data!.items.single.desc, 'A lake at dawn');
    });

    test('hides walls of a blocked creator without querying', () async {
      blocks.completeInitial(<String>{'blocked@x.com'});

      final result = await repo.fetchWalls(email: 'Blocked@x.com', refresh: true);

      expect(result.data!.items, isEmpty);
      expect(result.data!.hasMore, isFalse);
      expect(client.querySpecs, isEmpty);
    });

    test('a full page of twelve means there is more', () async {
      client.onQuery = (spec) => <FakeDocRow>[
        for (int i = 0; i < 12; i++) (id: 'w$i', data: <String, dynamic>{'wallpaper_url': 'u$i'}),
      ];

      final result = await repo.fetchWalls(email: 'a@x.com', refresh: true);

      expect(result.data!.items, hasLength(12));
      expect(result.data!.hasMore, isTrue);
    });

    test('a wall keeps its Firestore document id next to its own id', () async {
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-a', data: <String, dynamic>{'id': 'WALLA', 'wallpaper_url': 'https://example.test/a.jpg'}),
        (id: 'doc-b', data: <String, dynamic>{'wallpaper_url': 'https://example.test/b.jpg'}),
      ];

      final result = await repo.fetchWalls(email: 'a@x.com', refresh: true);

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
      final first = await repo.fetchWalls(email: 'creator@prism.test', refresh: true);
      expect(first.data!.items.single.id, 'offline-wall');

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restarted = PublicProfileRepositoryImpl(offlineClient, blocks);
      final restored = await restarted.fetchWalls(email: 'creator@prism.test', refresh: true);

      expect(restored.isSuccess, isTrue);
      expect(restored.data!.items.single.id, 'offline-wall');
      expect(restored.data!.items.single.wallpaperUrl, 'https://example.test/wall.jpg');
    });

    test('a wall keeps its Firestore document id after a restart restores it from the cache', () async {
      app_state.prismUser = profileUser(id: 'walls-document-id-owner');
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-a', data: <String, dynamic>{'id': 'WALLA', 'wallpaper_url': 'https://example.test/a.jpg'}),
      ];
      await repo.fetchWalls(email: 'creator@prism.test', refresh: true);
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-b', data: <String, dynamic>{'wallpaper_url': 'https://example.test/b.jpg'}),
      ];
      await repo.fetchWalls(email: 'creator@prism.test', refresh: false);

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restored = await PublicProfileRepositoryImpl(
        offlineClient,
        blocks,
      ).fetchWalls(email: 'creator@prism.test', refresh: true);

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
      await repo.fetchWalls(email: 'creator@prism.test', refresh: true);
      final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
      const String key = 'walls-corrupt-ids-owner::walls:creator@prism.test';
      await snapshots.write(key, <String, Object?>{...?await snapshots.read(key), 'documentIdsJson': '{'});

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restored = await PublicProfileRepositoryImpl(
        offlineClient,
        blocks,
      ).fetchWalls(email: 'creator@prism.test', refresh: true);

      expect(restored.isSuccess, isTrue);
      final walls = restored.data!.items.map((wall) => (wall.toFeedItem() as PrismFeedItem).wallpaper);
      expect(walls.map((wall) => (wall.id, wall.firestoreDocumentId)), <(String, String?)>[('WALLA', null)]);
    });

    test('a fetched next page is kept when the cached document id metadata is corrupt', () async {
      app_state.prismUser = profileUser(id: 'walls-corrupt-append-owner');
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-a', data: <String, dynamic>{'id': 'WALLA', 'wallpaper_url': 'https://example.test/a.jpg'}),
      ];
      await repo.fetchWalls(email: 'creator@prism.test', refresh: true);
      final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
      const String key = 'walls-corrupt-append-owner::walls:creator@prism.test';
      await snapshots.write(key, <String, Object?>{...?await snapshots.read(key), 'documentIdsJson': '[7]'});
      client.onQuery = (_) => <FakeDocRow>[
        (id: 'doc-b', data: <String, dynamic>{'wallpaper_url': 'https://example.test/b.jpg'}),
      ];

      final page = await repo.fetchWalls(email: 'creator@prism.test', refresh: false);

      expect(page.isSuccess, isTrue);
      expect(page.data!.items.map((wall) => wall.id), <String>['doc-b']);
      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restored = await PublicProfileRepositoryImpl(
        offlineClient,
        blocks,
      ).fetchWalls(email: 'creator@prism.test', refresh: true);
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
      final first = await repo.fetchWalls(email: 'creator@prism.test', refresh: true);
      expect(first.data!.items.map((wall) => wall.depthTier), <WallDepthTier?>[WallDepthTier.menu, null]);

      final offlineClient = _WatchingClient()..queryError = StateError('offline after restart');
      final restored = await PublicProfileRepositoryImpl(
        offlineClient,
        blocks,
      ).fetchWalls(email: 'creator@prism.test', refresh: true);

      expect(restored.data!.items.map((wall) => wall.depthTier), <WallDepthTier?>[WallDepthTier.menu, null]);
      expect((restored.data!.items.first.toFeedItem() as PrismFeedItem).wallpaper.depthTier, WallDepthTier.menu);
    });
  });
}
