import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/data/user_blocks/firebase_user_block_repository.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/profile_user_fixture.dart';

class _MockSession extends Mock implements SessionRepository {}

class _WatchingClient extends FakeFirestoreClient {
  final StreamController<List<FakeDocRow>> snapshots = StreamController<List<FakeDocRow>>.broadcast();
  final List<FirestoreQuerySpec> watchSpecs = <FirestoreQuerySpec>[];

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) {
    watchSpecs.add(spec);
    return snapshots.stream.map((rows) => rows.map((row) => map(row.data, row.id)).toList());
  }
}

FakeDocRow _blocked(String uid, String email, {Object? createdAt, String? username}) =>
    (id: uid, data: <String, dynamic>{'blockedEmail': email, 'blockedUsername': ?username, 'createdAt': ?createdAt});

void main() {
  late _MockSession session;
  late StreamController<PrismUsersV2> sessionUsers;
  late _WatchingClient client;

  setUp(() {
    session = _MockSession();
    sessionUsers = StreamController<PrismUsersV2>.broadcast();
    client = _WatchingClient();
    when(() => session.watchCurrentUser()).thenAnswer((_) => sessionUsers.stream);
    when(() => session.currentUser).thenReturn(profileUser(id: 'me'));
  });

  tearDown(() async {
    await sessionUsers.close();
    await client.snapshots.close();
  });

  test('a signed-in user gets a live, lowercased set from their blockedUsers collection', () async {
    final repo = FirebaseUserBlockRepository(session, client);

    sessionUsers.add(profileUser(id: 'me'));
    await pumpEventQueue();
    client.snapshots.add(<FakeDocRow>[_blocked('u1', ' Bad@X.com '), _blocked('u2', ''), _blocked('u3', 'b@x.com')]);

    expect(await repo.getBlockedCreatorEmails(waitForInitialLoad: true), <String>{'bad@x.com', 'b@x.com'});
    expect(client.watchSpecs.single.collection, 'usersv2/me/blockedUsers');
    expect(repo.cachedBlockedCreatorEmails, <String>{'bad@x.com', 'b@x.com'});
  });

  test('signing out clears the set', () async {
    final repo = FirebaseUserBlockRepository(session, client);
    sessionUsers.add(profileUser(id: 'me'));
    await pumpEventQueue();
    client.snapshots.add(<FakeDocRow>[_blocked('u1', 'bad@x.com')]);
    await pumpEventQueue();
    expect(repo.cachedBlockedCreatorEmails, isNotEmpty);

    sessionUsers.add(profileUser(id: 'me', loggedIn: false));
    await pumpEventQueue();

    expect(repo.cachedBlockedCreatorEmails, isEmpty);
  });

  group('fetchBlockedUsersList', () {
    test('lists newest first with undated rows last, and blank usernames become null', () async {
      client.onQuery = (spec) => <FakeDocRow>[
        _blocked('old', 'old@x.com', createdAt: DateTime.utc(2024)),
        _blocked('undated', 'undated@x.com'),
        _blocked('new', 'new@x.com', createdAt: DateTime.utc(2025), username: ' newbie '),
        _blocked('blank', 'blank@x.com', createdAt: DateTime.utc(2023), username: '  '),
      ];
      final repo = FirebaseUserBlockRepository(session, client);

      final rows = (await repo.fetchBlockedUsersList()).data!;

      expect(rows.map((r) => r.blockedUid), <String>['new', 'old', 'blank', 'undated']);
      expect(rows.first.blockedUsername, 'newbie');
      expect(rows[2].blockedUsername, isNull);
      expect(client.querySpecs.single.collection, 'usersv2/me/blockedUsers');
    });

    test('a signed-out user gets an empty list without a query', () async {
      when(() => session.currentUser).thenReturn(profileUser(loggedIn: false));
      final repo = FirebaseUserBlockRepository(session, client);

      expect((await repo.fetchBlockedUsersList()).data, isEmpty);
      expect(client.querySpecs, isEmpty);
    });

    test('a query error is a failure, not an empty list', () async {
      client.queryError = StateError('offline');
      final repo = FirebaseUserBlockRepository(session, client);

      expect((await repo.fetchBlockedUsersList()).failure, isA<ServerFailure>());
    });
  });

  test('block and unblock reject a blank user id before calling the server', () async {
    final repo = FirebaseUserBlockRepository(session, client);

    expect((await repo.blockUser(targetUserId: ' ')).failure, isA<ValidationFailure>());
    expect((await repo.unblockUser(targetUserId: '')).failure, isA<ValidationFailure>());
  });
}
