import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/public_profile/data/repositories/public_profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/profile_user_fixture.dart';

class _WatchingClient extends FakeFirestoreClient {
  final StreamController<List<FakeDocRow>> rows = StreamController<List<FakeDocRow>>();
  final List<FirestoreQuerySpec> watchSpecs = <FirestoreQuerySpec>[];
  Object? updateError;

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) {
    watchSpecs.add(spec);
    return rows.stream.map((list) => list.map((row) => map(row.data, row.id)).toList());
  }

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) {
    final Object? error = updateError;
    if (error != null) throw error;
    return super.updateDoc(collection, id, data, sourceTag: sourceTag);
  }
}

FakeDocRow _user(String email, {String name = ''}) =>
    (id: 'id_$email', data: <String, dynamic>{'email': email, 'name': name, 'username': email.split('@').first});

void main() {
  late _WatchingClient client;
  late FakeUserBlockRepository blocks;
  late PublicProfileRepositoryImpl repo;

  setUp(() {
    client = _WatchingClient();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    repo = PublicProfileRepositoryImpl(client, blocks);
  });

  group('watchProfile', () {
    test('looks a user up by email or by username', () {
      repo.watchProfile(' me@x.com ');
      repo.watchProfile('kevin');

      final fields = client.watchSpecs.map((spec) => spec.filters.single).toList();
      expect((fields[0].field, fields[0].value), ('email', 'me@x.com'));
      expect((fields[1].field, fields[1].value), ('username', 'kevin'));
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
    });

    test('unfollow touches the same fields and reports write errors as a failure', () async {
      await repo.unfollow(
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'them',
        targetUserEmail: 'them@x.com',
      );
      expect(client.writes.map((w) => w.data!.keys.single), <String>['following', 'followers']);

      client.updateError = StateError('offline');
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
  });
}
