// ignore_for_file: depend_on_referenced_packages, subtype_of_sealed_class, avoid_implementing_value_types

import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/content_reports/firebase_content_report_repository.dart';
import 'package:Prism/data/user_blocks/firebase_user_block_repository.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/profile_user_fixture.dart';

class _MockSession extends Mock implements SessionRepository {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _MockSnapshotMetadata extends Mock implements SnapshotMetadata {}

class _RecordingSink implements FirestoreTelemetrySink {
  final List<FirestoreTelemetryEvent> events = <FirestoreTelemetryEvent>[];

  @override
  Future<void> emit(FirestoreTelemetryEvent event) async => events.add(event);
}

class _FakeFunctions extends FirebaseFunctionsPlatform {
  _FakeFunctions(this.onCall) : super(null, 'asia-south1');

  Future<dynamic> Function(String name, dynamic parameters) onCall;

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

class _GatedReadStore extends DurableJsonStore {
  _GatedReadStore({required Directory directory, required this.readStarted, required this.releaseRead})
    : super('user_blocks', directory: directory);

  final Completer<void> readStarted;
  final Completer<void> releaseRead;

  @override
  Future<Map<String, Map<String, Object?>>> readAll() async {
    if (!readStarted.isCompleted) {
      readStarted.complete();
      await releaseRead.future;
    }
    return super.readAll();
  }
}

class _RetryFailingStore extends DurableJsonStore {
  _RetryFailingStore(this.retryReadStarted) : super('user_blocks');

  final Completer<void> retryReadStarted;
  var _reads = 0;

  @override
  Future<Map<String, Map<String, Object?>>> readAll() async {
    if (_reads++ == 0) return <String, Map<String, Object?>>{};
    retryReadStarted.complete();
    throw StateError('offline');
  }

  @override
  Future<Map<String, Object?>?> read(String key) async => null;
}

FakeDocRow _blocked(String uid, String email, {Object? createdAt, String? username}) => (
  id: uid,
  data: <String, dynamic>{
    'blockedEmail': email,
    'blockedUid': uid,
    'blockedUsername': ?username,
    'createdAt': ?createdAt,
  },
);

Future<void> _waitForWatchCount(_WatchingClient client, int count) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
  while (client.watchSpecs.length < count && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(client.watchSpecs.length, greaterThanOrEqualTo(count));
}

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
  late _FakeFunctions fakeFunctions;
  final Set<FirebaseUserBlockRepository> repositories = <FirebaseUserBlockRepository>{};

  FirebaseUserBlockRepository createRepository([DurableJsonStore? store]) {
    final repository = FirebaseUserBlockRepository(session, client, store: store);
    repositories.add(repository);
    return repository;
  }

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    previousFunctions = FirebaseFunctionsPlatform.instance;
    fakeFunctions = _FakeFunctions((name, parameters) async => <String, Object?>{'ok': true});
    FirebaseFunctionsPlatform.instance = fakeFunctions;
  });

  setUp(() async {
    storeDirectory = await Directory.systemTemp.createTemp('prism-user-blocks-test-');
    session = _MockSession();
    sessionUsers = StreamController<PrismUsersV2>.broadcast();
    client = _WatchingClient();
    when(() => session.watchCurrentUser()).thenAnswer((_) => sessionUsers.stream);
    when(() => session.currentUser).thenReturn(profileUser(id: 'me'));
    fakeFunctions.onCall = (name, parameters) async => <String, Object?>{'ok': true};
  });

  tearDown(() async {
    for (final repository in repositories) {
      await repository.dispose();
    }
    repositories.clear();
    await sessionUsers.close();
    await client.snapshots.close();
    if (await storeDirectory.exists()) await storeDirectory.delete(recursive: true);
  });

  tearDownAll(() => FirebaseFunctionsPlatform.instance = previousFunctions);

  test('a signed-in user gets blocked UIDs from document IDs, regardless of legacy email fields', () async {
    final repo = createRepository();

    sessionUsers.add(profileUser(id: 'me'));
    await client.watchStarted.future;
    client.snapshots.add(<FakeDocRow>[_blocked('u1', ' Bad@X.com '), _blocked('u2', ''), _blocked('u3', 'b@x.com')]);

    expect(await repo.getBlockedCreatorUids(waitForInitialLoad: true), <String>{'u1', 'u2', 'u3'});
    expect(client.watchSpecs.single.collection, 'usersv2/me/blockedUsers');
    expect(repo.cachedBlockedCreatorUids, <String>{'u1', 'u2', 'u3'});
  });

  test(
    'a persisted same-user block watch receives server data after Firebase takes longer than three seconds',
    () async {
      final ready = Completer<bool>();
      FirebaseInit.setFuture(ready.future);
      var initialized = false;
      var factoryCalls = 0;
      var attachments = 0;
      final attached = Completer<void>();
      final snapshots = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
        onListen: () {
          attachments++;
          attached.complete();
        },
      );
      final firestore = _MockFirestore();
      final collection = _MockCollection();
      final snapshot = _MockQuerySnapshot();
      final document = _MockQueryDoc();
      final metadata = _MockSnapshotMetadata();
      final sink = _RecordingSink();
      when(() => firestore.collection('usersv2/me/blockedUsers')).thenReturn(collection);
      when(() => collection.snapshots(includeMetadataChanges: false)).thenAnswer((_) => snapshots.stream);
      when(() => document.id).thenReturn('remote-blocked-creator');
      when(() => document.data()).thenReturn(<String, dynamic>{});
      when(() => snapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[document]);
      when(() => snapshot.metadata).thenReturn(metadata);
      when(() => metadata.isFromCache).thenReturn(false);
      final trackedClient = FirestoreTrackedClient.deferred(() {
        factoryCalls++;
        if (!initialized) throw FirebaseException(plugin: 'core', code: 'no-app');
        return firestore;
      }, sink);
      when(() => session.watchCurrentUser()).thenAnswer((_) async* {
        yield session.currentUser;
        yield* sessionUsers.stream;
      });
      final repo = FirebaseUserBlockRepository(
        session,
        trackedClient,
        store: DurableJsonStore('user_blocks', directory: storeDirectory),
      );
      repositories.add(repo);
      try {
        await Future<void>.delayed(const Duration(milliseconds: 3100));
        expect(factoryCalls, 0, reason: 'A timed-out bounded wait is not permission to access Firebase.');
        expect(snapshots.hasListener, isFalse);
        sessionUsers.add(profileUser(id: 'me'));
        initialized = true;
        ready.complete(true);
        await attached.future.timeout(const Duration(seconds: 2));

        final remoteBlocks = repo.watchBlockedCreatorUids().firstWhere(
          (uids) => uids.contains('remote-blocked-creator'),
        );
        snapshots.add(snapshot);
        expect(await remoteBlocks.timeout(const Duration(seconds: 2)), <String>{'remote-blocked-creator'});
        sessionUsers.add(profileUser(id: 'me'));
        await Future<void>.delayed(Duration.zero);
        expect(repo.cachedBlockedCreatorUids, <String>{'remote-blocked-creator'});
        expect(attachments, 1);
        expect(factoryCalls, 1);
        expect(sink.events.map((event) => (event.sourceTag, event.success)), <(String, bool)>[
          ('user_blocks.watch', true),
        ]);
      } finally {
        if (!ready.isCompleted) ready.complete(false);
        await repo.dispose();
        await snapshots.close();
      }
    },
  );

  test('a stream error keeps the last known set and ends the initial wait', () async {
    final repo = createRepository();
    sessionUsers.add(profileUser(id: 'me'));
    await client.watchStarted.future;

    final Future<Set<String>> afterInitialError = repo.watchBlockedCreatorUids().skip(1).first;
    client.snapshots.addError(StateError('permission-denied'));

    await afterInitialError;
    expect(await repo.getBlockedCreatorUids(waitForInitialLoad: true), isEmpty);

    final Future<Set<String>> afterSnapshot = repo.watchBlockedCreatorUids().firstWhere((uids) => uids.isNotEmpty);
    client.snapshots.add(<FakeDocRow>[_blocked('u1', 'bad@x.com')]);
    expect(await afterSnapshot, <String>{'u1'});

    final Future<Set<String>> afterLaterError = repo.watchBlockedCreatorUids().skip(1).first;
    client.snapshots.addError(StateError('unavailable'));
    expect(await afterLaterError, <String>{'u1'});

    expect(repo.cachedBlockedCreatorUids, <String>{'u1'});
  });

  test('a new account does not complete the initial block load with an unknown empty snapshot', () async {
    const String owner = 'unknown-block-snapshot-owner';
    when(() => session.currentUser).thenReturn(profileUser(id: owner));
    final repo = createRepository();
    sessionUsers.add(profileUser(id: owner));
    await client.watchStarted.future;
    var completed = false;
    final Future<Set<String>> waiting = repo.getBlockedCreatorUids(waitForInitialLoad: true).then((uids) {
      completed = true;
      return uids;
    });
    await expectLater(waiting.timeout(const Duration(milliseconds: 50)), throwsA(isA<TimeoutException>()));
    expect(completed, isFalse);
    client.snapshots.add(<FakeDocRow>[_blocked('blocked-id', 'blocked@x.com')]);
    expect(await waiting, <String>{'blocked-id'});
    expect(completed, isTrue);
  });

  test('waiting for the initial load gives up after 3 seconds and returns the cached set', () async {
    final repo = createRepository();
    fakeAsync((async) {
      Set<String>? result;
      unawaited(repo.getBlockedCreatorUids(waitForInitialLoad: true).then((value) => result = value));
      async.elapse(const Duration(seconds: 2));
      expect(result, isNull);
      async.elapse(const Duration(seconds: 2));

      expect(result, isEmpty);
    });
    await repo.dispose();
  });

  test('a timed-out initial load does not report creators as unblocked', () async {
    final repo = createRepository();
    fakeAsync((async) {
      sessionUsers.add(profileUser(id: 'me'));
      async.flushMicrotasks();
      Set<String>? result;
      unawaited(repo.getBlockedCreatorUids(waitForInitialLoad: true).then((value) => result = value));
      async.elapse(const Duration(seconds: 30));

      expect(result, isNotNull);
      expect(BlockedCreatorsFilter.hidesCreatorUid('blocked-creator', result!), isTrue);
    });
    await repo.dispose();
  });

  test('signing out clears the set', () async {
    final repo = createRepository();
    sessionUsers.add(profileUser(id: 'me'));
    await client.watchStarted.future;
    client.snapshots.add(<FakeDocRow>[_blocked('u1', 'bad@x.com')]);
    await repo.watchBlockedCreatorUids().firstWhere((uids) => uids.contains('u1'));
    expect(repo.cachedBlockedCreatorUids, isNotEmpty);

    final Future<Set<String>> signedOut = repo.watchBlockedCreatorUids().firstWhere((emails) => emails.isEmpty);
    sessionUsers.add(profileUser(id: 'me', loggedIn: false));
    await signedOut;

    expect(repo.cachedBlockedCreatorUids, isEmpty);
  });

  test('dispose waits for local hydration and stops lifecycle writes', () async {
    final Completer<void> readStarted = Completer<void>();
    final Completer<void> releaseRead = Completer<void>();
    final store = _GatedReadStore(directory: storeDirectory, readStarted: readStarted, releaseRead: releaseRead);
    final repo = createRepository(store);
    sessionUsers.add(profileUser(id: 'me'));
    await readStarted.future;

    sessionUsers.add(profileUser(id: 'me', loggedIn: false));
    await repo.watchBlockedCreatorUids().firstWhere((emails) => emails.isEmpty);
    var disposed = false;
    final Future<void> disposing = repo.dispose().then((_) => disposed = true);
    await Future<void>.delayed(Duration.zero);
    try {
      expect(disposed, isFalse);
      releaseRead.complete();
      await disposing;
    } finally {
      if (!releaseRead.isCompleted) releaseRead.complete();
    }
    expect(repo.cachedBlockedCreatorUids, isEmpty);
    expect(sessionUsers.hasListener, isFalse);
    expect(client.snapshots.hasListener, isFalse);
    expect(await store.readAll(), isEmpty);
    await storeDirectory.delete(recursive: true);
    sessionUsers.add(profileUser(id: 'late-user'));
    client.snapshots.add(<FakeDocRow>[_blocked('late', 'late@example.com')]);
    expect(await storeDirectory.exists(), isFalse);
  });

  test('dispose cancels pending retry backoff timers', () async {
    final List<Timer> retryTimers = <Timer>[];
    final Completer<void> retryTimerStarted = Completer<void>();
    await runZoned<Future<void>>(
      () async {
        final repo = createRepository(_RetryFailingStore(Completer<void>()));
        sessionUsers.add(profileUser(id: 'me'));
        await retryTimerStarted.future;
        expect(retryTimers, hasLength(1));
        expect(retryTimers.single.isActive, isTrue);

        await repo.dispose();

        expect(retryTimers.single.isActive, isFalse);
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createTimer(zone, duration, callback);
          retryTimers.add(timer);
          if (duration == const Duration(seconds: 2) && !retryTimerStarted.isCompleted) {
            retryTimerStarted.complete();
          }
          return timer;
        },
      ),
    );
  });

  test('restarts a cancelled owner retry when that owner becomes active again', () async {
    const String owner = 'retry-owner';
    final Completer<void> firstSendStarted = Completer<void>();
    final Completer<void> releaseFirstSend = Completer<void>();
    final Completer<void> replacementSendStarted = Completer<void>();
    var sends = 0;
    await DurableJsonStore('user_blocks').write('$owner::target', <String, Object?>{
      'owner': owner,
      'targetId': 'target',
      'email': 'target@example.com',
      'operationId': 'retry-owner:target:1',
      'desired': true,
      'status': 'pending',
    });
    fakeFunctions.onCall = (name, parameters) async {
      sends++;
      if (sends == 1) {
        firstSendStarted.complete();
        await releaseFirstSend.future;
      } else {
        replacementSendStarted.complete();
      }
      return <String, Object?>{'ok': true};
    };
    final repo = createRepository();

    when(() => session.currentUser).thenReturn(profileUser(id: owner));
    sessionUsers.add(profileUser(id: owner));
    try {
      await firstSendStarted.future.timeout(const Duration(seconds: 2));
      when(() => session.currentUser).thenReturn(profileUser(id: 'other-owner'));
      sessionUsers.add(profileUser(id: 'other-owner'));
      await _waitForWatchCount(client, 2);
      final Future<Set<String>> returnedOwnerSnapshot = repo.watchBlockedCreatorUids().firstWhere(
        (uids) => uids.contains('target'),
      );
      when(() => session.currentUser).thenReturn(profileUser(id: owner));
      sessionUsers.add(profileUser(id: owner));
      await _waitForWatchCount(client, 3);
      await returnedOwnerSnapshot.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sends, 1);
      releaseFirstSend.complete();
      await replacementSendStarted.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('replacement retry did not start after the original send completed'),
      );
      expect(sends, 2);
    } finally {
      if (!releaseFirstSend.isCompleted) releaseFirstSend.complete();
      await repo.dispose();
    }
  });

  test('dispose does not restart a cancelled retry after its send completes', () async {
    const String owner = 'disposed-retry-owner';
    final Completer<void> sendStarted = Completer<void>();
    final Completer<void> releaseSend = Completer<void>();
    var sends = 0;
    await DurableJsonStore('user_blocks').write('$owner::target', <String, Object?>{
      'owner': owner,
      'targetId': 'target',
      'operationId': 'disposed-retry-owner:target:1',
      'desired': true,
      'status': 'pending',
    });
    fakeFunctions.onCall = (name, parameters) async {
      sends++;
      sendStarted.complete();
      await releaseSend.future;
      return <String, Object?>{'ok': true};
    };
    final repo = createRepository();
    when(() => session.currentUser).thenReturn(profileUser(id: owner));
    sessionUsers.add(profileUser(id: owner));
    try {
      await sendStarted.future.timeout(const Duration(seconds: 2));
      final Future<void> firstDispose = repo.dispose();
      expect(identical(firstDispose, repo.dispose()), isTrue);
      releaseSend.complete();
      await firstDispose;
      expect(sends, 1);
    } finally {
      if (!releaseSend.isCompleted) releaseSend.complete();
      await repo.dispose();
    }
  });

  test('clearForUser waits for prior block writes and prevents later snapshot writes', () async {
    const String owner = 'me';
    final repo = createRepository();
    final DurableJsonStore store = DurableJsonStore('user_blocks');
    await store.write('$owner::existing', <String, Object?>{'owner': owner});
    await store.write('other-owner::existing', <String, Object?>{'owner': 'other-owner'});

    await repo.clearForUser(owner);

    expect(await store.read('$owner::existing'), isNull);
    expect(await store.read('other-owner::existing'), isNotNull);
    final blocked = await repo.blockUser(targetUserId: 'late-target');
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
      final repo = createRepository();

      final rows = (await repo.fetchBlockedUsersList()).data!;

      expect(rows.map((r) => r.blockedUid), <String>['new', 'old', 'blank', 'undated']);
      expect(rows.first.blockedUsername, 'newbie');
      expect(rows[2].blockedUsername, isNull);
      expect(client.querySpecs.single.collection, 'usersv2/me/blockedUsers');
    });

    test('a signed-out user gets an empty list without a query', () async {
      when(() => session.currentUser).thenReturn(profileUser(loggedIn: false));
      final repo = createRepository();

      expect((await repo.fetchBlockedUsersList()).data, isEmpty);
      expect(client.querySpecs, isEmpty);
    });

    test('a query error is a failure, not an empty list', () async {
      when(() => session.currentUser).thenReturn(profileUser(id: 'block-query-error-owner'));
      client.queryError = StateError('offline');
      final repo = createRepository();

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
      final repo = createRepository();

      expect((await repo.fetchBlockedUsersList()).failure, isA<ServerFailure>());
    });

    test('a confirmed empty server snapshot remains a valid offline result', () async {
      const String owner = 'block-empty-snapshot-owner';
      when(() => session.currentUser).thenReturn(profileUser(id: owner));
      client.onQuery = (_) => <FakeDocRow>[];
      final repo = createRepository();

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
      final repo = createRepository();

      final result = await repo.fetchBlockedUsersList();
      expect(result.isSuccess, isTrue);
      expect(result.data!.single.blockedUid, 'target');
      expect(result.data!.single.syncStatus, 'pending');
    });

    test('server rows survive repository restart and are returned when the next query is offline', () async {
      const String owner = 'block-snapshot-restart-owner';
      when(() => session.currentUser).thenReturn(profileUser(id: owner));
      client.onQuery = (spec) => <FakeDocRow>[_blocked('saved-target', 'saved@example.com', username: 'saved_user')];
      final repo = createRepository();
      final first = await repo.fetchBlockedUsersList();
      expect(first.data!.single.blockedUid, 'saved-target');

      client.queryError = StateError('offline after restart');
      final restarted = createRepository();
      final restored = await restarted.fetchBlockedUsersList();

      expect(restored.isSuccess, isTrue);
      expect(restored.data!.single.blockedUid, 'saved-target');
      expect(restored.data!.single.blockedUsername, 'saved_user');
      expect(restored.data!.single.syncStatus, 'synced');
    });
  });

  test('last known blocked UIDs restore after a repository restart before network refresh', () async {
    const String owner = 'blocked-uid-restart-owner';
    when(() => session.currentUser).thenReturn(profileUser(id: owner));
    final first = createRepository();
    sessionUsers.add(profileUser(id: owner));
    await client.watchStarted.future;
    client.snapshots.add(<FakeDocRow>[_blocked('saved-target', 'Saved@Example.com')]);
    await first.watchBlockedCreatorUids().firstWhere((uids) => uids.contains('saved-target'));
    expect(first.cachedBlockedCreatorUids, <String>{'saved-target'});

    final restarted = createRepository();
    sessionUsers.add(profileUser(id: owner));
    expect(await restarted.getBlockedCreatorUids(waitForInitialLoad: true), <String>{'saved-target'});

    expect(restarted.cachedBlockedCreatorUids, <String>{'saved-target'});
  });

  test('legacy email cache snapshots are not interpreted as blocked UIDs', () async {
    const String owner = 'legacy-email-cache-owner';
    when(() => session.currentUser).thenReturn(profileUser(id: owner));
    final store = DurableJsonStore('user_blocks');
    await store.write('$owner::server_emails', <String, Object?>{'emailsJson': '["private@example.com"]'});
    final repo = createRepository(store);
    sessionUsers.add(profileUser(id: owner));
    await client.watchStarted.future;
    client.snapshots.add(<FakeDocRow>[]);

    expect(await repo.getBlockedCreatorUids(waitForInitialLoad: true), isEmpty);
  });

  test('block and unblock reject a blank user id before calling the server', () async {
    final repo = createRepository();

    expect((await repo.blockUser(targetUserId: ' ')).failure, isA<ValidationFailure>());
    expect((await repo.unblockUser(targetUserId: '')).failure, isA<ValidationFailure>());
  });

  test('content reports validate before sending and preserve server and transport errors', () async {
    final repository = FirebaseContentReportRepository();
    final calls = <Object?>[];
    fakeFunctions.onCall = (name, parameters) async {
      expect(name, 'submitContentReport');
      calls.add(parameters);
      return <String, Object?>{'ok': true};
    };
    expect(
      (await repository.submitReport(contentType: ' ', targetFirestoreDocId: 'wall', reason: 'spam')).isFailure,
      isTrue,
    );
    expect(calls, isEmpty);
    expect(
      (await repository.submitReport(
        contentType: ' wall ',
        targetFirestoreDocId: ' id ',
        reason: ' spam ',
        details: ' detail ',
        appVersion: ' 1.0 ',
      )).isSuccess,
      isTrue,
    );
    expect(calls.single, <String, String>{
      'contentType': 'wall',
      'targetFirestoreDocId': 'id',
      'reason': 'spam',
      'details': 'detail',
      'appVersion': '1.0',
    });
    fakeFunctions.onCall = (_, _) async =>
        throw cf.FirebaseFunctionsException(code: 'permission-denied', message: 'Report denied');
    expect(
      (await repository.submitReport(contentType: 'wall', targetFirestoreDocId: 'id', reason: 'spam')).failure!.message,
      'Report denied',
    );
    fakeFunctions.onCall = (_, _) async => throw StateError('offline');
    expect(
      (await repository.submitReport(contentType: 'wall', targetFirestoreDocId: 'id', reason: 'spam')).failure!.message,
      contains('Failed to submit report:'),
    );
  });

  for (final bool block in <bool>[true, false]) {
    for (final Object error in <Object>[
      cf.FirebaseFunctionsException(code: 'permission-denied', message: 'Target denied'),
      cf.FirebaseFunctionsException(code: 'unavailable', message: 'Try later'),
      StateError('offline'),
    ]) {
      test('${block ? 'block' : 'unblock'} keeps local intent with correct sync status after $error', () async {
        final repo = createRepository();
        sessionUsers.add(profileUser(id: 'me'));
        await client.watchStarted.future;
        client.snapshots.add(<FakeDocRow>[]);
        await repo.getBlockedCreatorUids(waitForInitialLoad: true);
        final calls = <String>[];
        fakeFunctions.onCall = (name, parameters) {
          calls.add(name);
          expect(parameters, <String, String>{'targetUserId': 'target'});
          return Future<dynamic>.error(error);
        };
        final result = block
            ? await repo.blockUser(targetUserId: ' target ')
            : await repo.unblockUser(targetUserId: ' target ');
        final permanent = error is cf.FirebaseFunctionsException && error.code == 'permission-denied';
        expect(result.failure!.message, permanent ? 'Target denied' : startsWith('Pending sync:'));
        await repo.dispose();
        final record = await DurableJsonStore('user_blocks').read('me::target');
        expect(record!['desired'], block);
        expect(record['status'], permanent ? 'rejected' : 'pending');
        expect(calls, everyElement(block ? 'blockUser' : 'unblockUser'));
        expect(calls, isNotEmpty);
        if (block) expect(record.containsKey('email'), isFalse);
      });
    }
  }

  test('pending unblocks remove server rows while rejected blocks retain their explanation offline', () async {
    final store = DurableJsonStore('user_blocks');
    await store.write('me::remove', <String, Object?>{
      'owner': 'me',
      'targetId': 'remove',
      'desired': false,
      'status': 'pending',
    });
    await store.write('me::add', <String, Object?>{
      'owner': 'me',
      'targetId': 'add',
      'email': 'add@example.com',
      'username': 'Added',
      'desired': true,
      'status': 'rejected',
    });
    client.onQuery = (_) => <FakeDocRow>[
      _blocked('remove', 'remove@example.com'),
      _blocked('keep', 'keep@example.com'),
    ];
    final repo = createRepository();
    final online = (await repo.fetchBlockedUsersList()).data!;
    expect(online.map((row) => row.blockedUid), <String>['keep', 'add']);
    expect(online.last.syncStatus, 'rejected');
    expect(online.last.blockedUsername, 'Added');
    client.queryError = StateError('offline');
    final offline = (await repo.fetchBlockedUsersList()).data!;
    expect(offline.map((row) => row.blockedUid), <String>['keep', 'add']);
    expect(offline.last.syncStatus, 'rejected');
  });

  for (final Object retryError in <Object>[
    cf.FirebaseFunctionsException(code: 'invalid-argument', message: 'Invalid target'),
    cf.FirebaseFunctionsException(code: 'unavailable', message: 'Retry later'),
    StateError('connection lost'),
  ]) {
    test('restored pending intent records retry failure $retryError durably', () async {
      final store = DurableJsonStore('user_blocks');
      await store.write('me::target', <String, Object?>{
        'owner': 'me',
        'targetId': 'target',
        'operationId': 'me:target:1',
        'desired': false,
        'status': 'pending',
      });
      final attempted = Completer<void>();
      fakeFunctions.onCall = (name, parameters) {
        expect(name, 'unblockUser');
        expect(parameters, <String, String>{'targetUserId': 'target'});
        attempted.complete();
        return Future<dynamic>.error(retryError);
      };
      final repo = createRepository();
      sessionUsers.add(profileUser(id: 'me'));
      await attempted.future;
      await repo.dispose();
      final record = (await store.read('me::target'))!;
      final rejected = retryError is cf.FirebaseFunctionsException && retryError.code == 'invalid-argument';
      expect(record['status'], rejected ? 'rejected' : 'pending');
      expect(record['error'], retryError is cf.FirebaseFunctionsException ? retryError.message : retryError.toString());
      if (!rejected) expect(record['attempts'], 1);
    });
  }

  test('a stalled block send does not block local reads or newer intent writes', () async {
    const String owner = 'stalled-block-owner';
    const String target = 'target-user';
    when(() => session.currentUser).thenReturn(profileUser(id: owner));
    final Completer<void> sendStarted = Completer<void>();
    final Completer<void> releaseSend = Completer<void>();
    final Completer<void> newerSendStarted = Completer<void>();
    final Completer<void> releaseNewerSend = Completer<void>();
    fakeFunctions.onCall = (name, parameters) async {
      if (name == 'blockUser') {
        sendStarted.complete();
        await releaseSend.future;
      } else if (name == 'unblockUser') {
        newerSendStarted.complete();
        await releaseNewerSend.future;
      }
      return <String, Object?>{'ok': true};
    };
    final repo = createRepository();
    sessionUsers.add(profileUser(id: owner));
    await client.watchStarted.future;
    client.snapshots.add(<FakeDocRow>[_blocked(target, 'target@example.com')]);
    await repo.watchBlockedCreatorUids().firstWhere((uids) => uids.contains(target));

    final Future<dynamic> oldBlock = repo.blockUser(targetUserId: target);
    await sendStarted.future;

    final Future<Set<String>> unblockedUid = repo.watchBlockedCreatorUids().firstWhere((uids) => uids.isEmpty);
    final Future<dynamic> newUnblock = repo.unblockUser(targetUserId: target);
    try {
      await unblockedUid.timeout(const Duration(seconds: 10));
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
