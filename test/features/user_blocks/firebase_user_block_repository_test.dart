// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/user_blocks/firebase_user_block_repository.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/profile_user_fixture.dart';

class _MockSession extends Mock implements SessionRepository {}

class _FakeFunctions extends FirebaseFunctionsPlatform {
  _FakeFunctions(this.onCall) : super(null, 'asia-south1');

  final Future<dynamic> Function(String name, dynamic parameters) onCall;

  @override
  FirebaseFunctionsPlatform delegateFor({FirebaseApp? app, required String region}) => this;

  @override
  HttpsCallablePlatform httpsCallable(String? origin, String name, HttpsCallableOptions options) =>
      _FakeCallable(this, origin, name, options);
}

class _FakeCallable extends HttpsCallablePlatform {
  _FakeCallable(_FakeFunctions functions, String? origin, String name, HttpsCallableOptions options)
    : super(functions, origin, name, options, null);

  @override
  Future<dynamic> call([dynamic parameters]) => (functions as _FakeFunctions).onCall(name!, parameters);
}

class _WatchingClient extends FakeFirestoreClient {
  final StreamController<List<FakeDocRow>> snapshots = StreamController<List<FakeDocRow>>.broadcast();
  final List<FirestoreQuerySpec> watchSpecs = <FirestoreQuerySpec>[];
  final Completer<void> watchStarted = Completer<void>();

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) {
    watchSpecs.add(spec);
    if (!watchStarted.isCompleted) watchStarted.complete();
    return snapshots.stream.map((rows) => rows.map((row) => map(row.data, row.id)).toList());
  }
}

FakeDocRow _blocked(String uid, String email, {Object? createdAt, String? username}) =>
    (id: uid, data: <String, dynamic>{'blockedEmail': email, 'blockedUsername': ?username, 'createdAt': ?createdAt});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storeDirectory;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => storeDirectory.path,
  );
  late _MockSession session;
  late StreamController<PrismUsersV2> sessionUsers;
  late _WatchingClient client;
  late FirebaseFunctionsPlatform previousFunctions;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    previousFunctions = FirebaseFunctionsPlatform.instance;
  });

  setUp(() async {
    storeDirectory = await Directory.systemTemp.createTemp('prism-user-blocks-test-');
    session = _MockSession();
    sessionUsers = StreamController<PrismUsersV2>.broadcast();
    client = _WatchingClient();
    when(() => session.watchCurrentUser()).thenAnswer((_) => sessionUsers.stream);
    when(() => session.currentUser).thenReturn(profileUser(id: 'me'));
  });

  tearDown(() async {
    await sessionUsers.close();
    await client.snapshots.close();
    await storeDirectory.delete(recursive: true);
  });

  tearDownAll(() => FirebaseFunctionsPlatform.instance = previousFunctions);

  test('a signed-in user gets a live, lowercased set from their blockedUsers collection', () async {
    final repo = FirebaseUserBlockRepository(session, client);

    sessionUsers.add(profileUser(id: 'me'));
    await client.watchStarted.future;
    client.snapshots.add(<FakeDocRow>[_blocked('u1', ' Bad@X.com '), _blocked('u2', ''), _blocked('u3', 'b@x.com')]);

    expect(await repo.getBlockedCreatorEmails(waitForInitialLoad: true), <String>{'bad@x.com', 'b@x.com'});
    expect(client.watchSpecs.single.collection, 'usersv2/me/blockedUsers');
    expect(repo.cachedBlockedCreatorEmails, <String>{'bad@x.com', 'b@x.com'});
  });

  test('a stream error keeps the last known set and ends the initial wait', () async {
    final repo = FirebaseUserBlockRepository(session, client);
    sessionUsers.add(profileUser(id: 'me'));
    await client.watchStarted.future;

    final Future<Set<String>> afterInitialError = repo.watchBlockedCreatorEmails().skip(1).first;
    client.snapshots.addError(StateError('permission-denied'));

    await afterInitialError;
    expect(await repo.getBlockedCreatorEmails(waitForInitialLoad: true), isEmpty);

    final Future<Set<String>> afterSnapshot = repo.watchBlockedCreatorEmails().skip(1).first;
    client.snapshots.add(<FakeDocRow>[_blocked('u1', 'bad@x.com')]);
    expect(await afterSnapshot, <String>{'bad@x.com'});

    final Future<Set<String>> afterLaterError = repo.watchBlockedCreatorEmails().skip(1).first;
    client.snapshots.addError(StateError('unavailable'));
    expect(await afterLaterError, <String>{'bad@x.com'});

    expect(repo.cachedBlockedCreatorEmails, <String>{'bad@x.com'});
  });

  test('a new account does not complete the initial block load with an unknown empty snapshot', () async {
    const String owner = 'unknown-block-snapshot-owner';
    when(() => session.currentUser).thenReturn(profileUser(id: owner));
    final repo = FirebaseUserBlockRepository(session, client);
    sessionUsers.add(profileUser(id: owner));
    await client.watchStarted.future;
    var completed = false;
    final Future<Set<String>> waiting = repo.getBlockedCreatorEmails(waitForInitialLoad: true).then((emails) {
      completed = true;
      return emails;
    });
    await expectLater(waiting.timeout(const Duration(milliseconds: 50)), throwsA(isA<TimeoutException>()));
    expect(completed, isFalse);
    client.snapshots.add(<FakeDocRow>[_blocked('blocked-id', 'blocked@x.com')]);
    expect(await waiting, <String>{'blocked@x.com'});
    expect(completed, isTrue);
  });

  test('waiting for the initial load gives up after 3 seconds and returns the cached set', () {
    fakeAsync((async) {
      final repo = FirebaseUserBlockRepository(session, client);
      sessionUsers.add(profileUser(id: 'me'));
      async.flushMicrotasks();

      Set<String>? result;
      unawaited(repo.getBlockedCreatorEmails(waitForInitialLoad: true).then((value) => result = value));
      async.elapse(const Duration(seconds: 2));
      expect(result, isNull);
      async.elapse(const Duration(seconds: 2));

      expect(result, isEmpty);
    });
  });

  test('signing out clears the set', () async {
    final repo = FirebaseUserBlockRepository(session, client);
    sessionUsers.add(profileUser(id: 'me'));
    await client.watchStarted.future;
    client.snapshots.add(<FakeDocRow>[_blocked('u1', 'bad@x.com')]);
    await repo.watchBlockedCreatorEmails().firstWhere((emails) => emails.contains('bad@x.com'));
    expect(repo.cachedBlockedCreatorEmails, isNotEmpty);

    final Future<Set<String>> signedOut = repo.watchBlockedCreatorEmails().firstWhere((emails) => emails.isEmpty);
    sessionUsers.add(profileUser(id: 'me', loggedIn: false));
    await signedOut;

    expect(repo.cachedBlockedCreatorEmails, isEmpty);
  });

  test('clearForUser waits for prior block writes and prevents later snapshot writes', () async {
    const String owner = 'me';
    final repo = FirebaseUserBlockRepository(session, client);
    final DurableJsonStore store = DurableJsonStore('user_blocks');
    await store.write('$owner::existing', <String, Object?>{'owner': owner});
    await store.write('other-owner::existing', <String, Object?>{'owner': 'other-owner'});

    await repo.clearForUser(owner);

    expect(await store.read('$owner::existing'), isNull);
    expect(await store.read('other-owner::existing'), isNotNull);
    final blocked = await repo.blockUser(targetUserId: 'late-target', targetEmail: 'late@x.com');
    expect(blocked.isSuccess, isFalse);
    expect(await store.read('$owner::late-target'), isNull);
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
      when(() => session.currentUser).thenReturn(profileUser(id: 'block-query-error-owner'));
      client.queryError = StateError('offline');
      final repo = FirebaseUserBlockRepository(session, client);

      expect((await repo.fetchBlockedUsersList()).failure, isA<ServerFailure>());
    });

    test('an unknown snapshot is not accepted when only another owner has a local record', () async {
      const String owner = 'block-unknown-snapshot-owner';
      when(() => session.currentUser).thenReturn(profileUser(id: owner));
      client.queryError = StateError('offline');
      await DurableJsonStore('user_blocks').write('someone-else::target', <String, Object?>{
        'owner': 'someone-else',
        'targetId': 'target',
        'desired': true,
        'status': 'pending',
      });
      await DurableJsonStore('user_blocks').write('$owner::wrong-owner-target', <String, Object?>{
        'owner': 'someone-else',
        'targetId': 'wrong-owner-target',
        'desired': true,
        'status': 'pending',
      });
      final repo = FirebaseUserBlockRepository(session, client);

      expect((await repo.fetchBlockedUsersList()).failure, isA<ServerFailure>());
    });

    test('a confirmed empty server snapshot remains a valid offline result', () async {
      const String owner = 'block-empty-snapshot-owner';
      when(() => session.currentUser).thenReturn(profileUser(id: owner));
      client.onQuery = (_) => <FakeDocRow>[];
      final repo = FirebaseUserBlockRepository(session, client);

      expect((await repo.fetchBlockedUsersList()).data, isEmpty);
      client.queryError = StateError('offline');

      expect((await repo.fetchBlockedUsersList()).data, isEmpty);
    });

    test('a valid local pending intent is available when the query is offline', () async {
      const String owner = 'block-pending-intent-owner';
      when(() => session.currentUser).thenReturn(profileUser(id: owner));
      client.queryError = StateError('offline');
      await DurableJsonStore('user_blocks').write('$owner::target', <String, Object?>{
        'owner': owner,
        'targetId': 'target',
        'email': 'target@example.com',
        'desired': true,
        'status': 'pending',
      });
      final repo = FirebaseUserBlockRepository(session, client);

      final result = await repo.fetchBlockedUsersList();
      expect(result.isSuccess, isTrue);
      expect(result.data!.single.blockedUid, 'target');
      expect(result.data!.single.syncStatus, 'pending');
    });

    test('server rows survive repository restart and are returned when the next query is offline', () async {
      const String owner = 'block-snapshot-restart-owner';
      when(() => session.currentUser).thenReturn(profileUser(id: owner));
      client.onQuery = (spec) => <FakeDocRow>[_blocked('saved-target', 'saved@example.com', username: 'saved_user')];
      final repo = FirebaseUserBlockRepository(session, client);
      final first = await repo.fetchBlockedUsersList();
      expect(first.data!.single.blockedUid, 'saved-target');

      client.queryError = StateError('offline after restart');
      final restarted = FirebaseUserBlockRepository(session, client);
      final restored = await restarted.fetchBlockedUsersList();

      expect(restored.isSuccess, isTrue);
      expect(restored.data!.single.blockedUid, 'saved-target');
      expect(restored.data!.single.blockedUsername, 'saved_user');
      expect(restored.data!.single.syncStatus, 'synced');
    });
  });

  test('last known blocked emails restore after a repository restart before network refresh', () async {
    const String owner = 'blocked-email-restart-owner';
    when(() => session.currentUser).thenReturn(profileUser(id: owner));
    final first = FirebaseUserBlockRepository(session, client);
    sessionUsers.add(profileUser(id: owner));
    await client.watchStarted.future;
    client.snapshots.add(<FakeDocRow>[_blocked('saved-target', 'Saved@Example.com')]);
    await first.watchBlockedCreatorEmails().firstWhere((emails) => emails.contains('saved@example.com'));
    expect(first.cachedBlockedCreatorEmails, <String>{'saved@example.com'});

    final restarted = FirebaseUserBlockRepository(session, client);
    sessionUsers.add(profileUser(id: owner));
    expect(await restarted.getBlockedCreatorEmails(waitForInitialLoad: true), <String>{'saved@example.com'});

    expect(restarted.cachedBlockedCreatorEmails, <String>{'saved@example.com'});
  });

  test('block and unblock reject a blank user id before calling the server', () async {
    final repo = FirebaseUserBlockRepository(session, client);

    expect((await repo.blockUser(targetUserId: ' ')).failure, isA<ValidationFailure>());
    expect((await repo.unblockUser(targetUserId: '')).failure, isA<ValidationFailure>());
  });

  test('a stalled block send does not block local reads or newer intent writes', () async {
    const String owner = 'stalled-block-owner';
    const String target = 'target-user';
    when(() => session.currentUser).thenReturn(profileUser(id: owner));
    final Completer<void> sendStarted = Completer<void>();
    final Completer<void> releaseSend = Completer<void>();
    final Completer<void> newerSendStarted = Completer<void>();
    final Completer<void> releaseNewerSend = Completer<void>();
    FirebaseFunctionsPlatform.instance = _FakeFunctions((name, parameters) async {
      if (name == 'blockUser') {
        sendStarted.complete();
        await releaseSend.future;
      } else if (name == 'unblockUser') {
        newerSendStarted.complete();
        await releaseNewerSend.future;
      }
      return <String, Object?>{'ok': true};
    });
    final repo = FirebaseUserBlockRepository(session, client);
    sessionUsers.add(profileUser(id: owner));
    await client.watchStarted.future;
    client.snapshots.add(<FakeDocRow>[_blocked(target, 'target@example.com')]);
    await repo.watchBlockedCreatorEmails().firstWhere((emails) => emails.contains('target@example.com'));

    final Future<dynamic> oldBlock = repo.blockUser(targetUserId: target, targetEmail: 'target@example.com');
    await sendStarted.future;

    final Future<Set<String>> unblockedEmail = repo.watchBlockedCreatorEmails().firstWhere((emails) => emails.isEmpty);
    final Future<dynamic> newUnblock = repo.unblockUser(targetUserId: target);
    try {
      await unblockedEmail.timeout(const Duration(seconds: 10));
      final results = await Future.wait<Object?>(<Future<Object?>>[
        DurableJsonStore('user_blocks').read('$owner::$target'),
        repo.fetchBlockedUsersList(),
      ]).timeout(const Duration(seconds: 10));
      final Map<String, Object?>? currentBeforeRelease = results[0] as Map<String, Object?>?;
      expect(currentBeforeRelease?['desired'], false);
      expect(currentBeforeRelease?['revision'], 2);
      expect((results[1] as Result<List<BlockedUserListRow>>).isSuccess, isTrue);
    } finally {
      releaseSend.complete();
    }

    await newerSendStarted.future;
    final Map<String, Object?>? afterOldResponse = await DurableJsonStore('user_blocks').read('$owner::$target');
    expect(afterOldResponse?['desired'], false);
    expect(afterOldResponse?['status'], 'pending');
    releaseNewerSend.complete();

    expect((await oldBlock).isSuccess, isTrue);
    expect((await newUnblock).isSuccess, isTrue);
    final Map<String, Object?>? latest = await DurableJsonStore('user_blocks').read('$owner::$target');
    expect(latest?['desired'], false);
    expect(latest?['revision'], 2);
    expect(latest?['status'], 'synced');
  });
}
