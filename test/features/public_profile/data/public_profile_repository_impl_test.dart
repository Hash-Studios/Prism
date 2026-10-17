import 'dart:async';
import 'dart:io';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/public_profile/data/repositories/public_profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/profile_user_fixture.dart';

class _WatchingClient extends FakeFirestoreClient {
  final StreamController<List<FakeDocRow>> rows = StreamController<List<FakeDocRow>>();
  final List<FirestoreQuerySpec> watchSpecs = <FirestoreQuerySpec>[];
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
    return rows.stream.map((list) => list.map((row) => map(row.data, row.id)).toList());
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
  });

  tearDown(() async {
    await storeDirectory.delete(recursive: true);
  });

  group('watchProfile', () {
    test('looks a user up by email or by username', () async {
      final first = repo.watchProfile(' me@x.com ').listen((_) {});
      final second = repo.watchProfile('kevin').listen((_) {});
      await Future<void>.delayed(Duration.zero);

      final fields = client.watchSpecs.map((spec) => spec.filters.single).toList();
      expect((fields[0].field, fields[0].value), ('email', 'me@x.com'));
      expect((fields[1].field, fields[1].value), ('username', 'kevin'));
      await first.cancel();
      await second.cancel();
    });

    test('emits the profile, or null when nobody matches', () async {
      final emitted = <String?>[];
      final sub = repo.watchProfile('a@x.com').listen((profile) => emitted.add(profile?.name));

      client.rows.add(<FakeDocRow>[_user('a@x.com', name: 'Ana')]);
      client.rows.add(const <FakeDocRow>[]);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emitted, <String?>['Ana', null]);
    });

    test('uses the document id, which follow and block calls need', () async {
      final profiles = <String>[];
      final sub = repo.watchProfile('a@x.com').listen((profile) => profiles.add(profile!.id));

      client.rows.add(<FakeDocRow>[_user('a@x.com')]);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(profiles, <String>['id_a@x.com']);
    });

    test('maps server badge objects and accepts profiles from before badges existed', () async {
      final badgeIds = <List<String>>[];
      final sub = repo.watchProfile('a@x.com').listen((profile) => badgeIds.add(profile!.badges));
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
      await Future<void>.delayed(Duration.zero);
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
      await Future<void>.delayed(Duration.zero);
      client.rows.add(<FakeDocRow>[
        (id: 'large-profile', data: <String, dynamic>{'email': 'large-profile@x.com', 'name': name}),
      ]);

      expect(await receivedNameLength.future.timeout(const Duration(seconds: 2)), name.length);
      await subscription.cancel();
    });

    test('a profile snapshot is available after restart before the next remote snapshot', () async {
      const email = 'offline-profile-snapshot@prism.test';
      final Completer<void> received = Completer<void>();
      final subscription = repo.watchProfile(email).listen((profile) {
        if (profile?.name == 'Saved profile' && !received.isCompleted) received.complete();
      });
      await Future<void>.delayed(Duration.zero);
      client.rows.add(<FakeDocRow>[_user(email, name: 'Saved profile')]);
      await received.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await subscription.cancel();

      final restarted = PublicProfileRepositoryImpl(_WatchingClient(), blocks);
      final cached = await restarted.watchProfile(email).first.timeout(const Duration(seconds: 2));

      expect(cached?.name, 'Saved profile');
    });
  });

  test('a profile stream write that arrives after owner cleanup cannot restore the snapshot', () async {
    app_state.prismUser = profileUser(id: 'profile-owner');
    const String email = 'late-profile@prism.test';
    final subscription = repo.watchProfile(email).listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await repo.clearForUser('profile-owner');

    client.rows.add(<FakeDocRow>[_user(email, name: 'Late profile')]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await subscription.cancel();

    final DurableJsonStore snapshots = DurableJsonStore('public_profiles');
    expect(await snapshots.read('profile-owner::${email.toLowerCase()}'), isNull);
    app_state.prismUser = profileUser(id: '', loggedIn: false);
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
      expect(client.querySpecs.single.filters.single.value, <String>['a@x.com']);
    });
  });

  group('fetchWalls', () {
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
  });
}
