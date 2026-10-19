import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/features/admin_review/biz/bloc/review_batch_bloc.dart';
import 'package:Prism/features/admin_review/biz/depth_override.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/data/review_batch_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _BatchFirestoreClient extends FakeFirestoreClient {
  _BatchFirestoreClient({super.docs});

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) {
    return action(_DocsBatch(this));
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) {
    return action(_DocsBatch(this));
  }
}

class _RejectingUpdateClient extends _BatchFirestoreClient {
  _RejectingUpdateClient({super.docs});

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) =>
      Future<void>.error(StateError('permission-denied'));
}

/// Lets a test hold a write open (or fail it) by call number, to check the order of depth writes.
class _ControlledUpdateClient extends _BatchFirestoreClient {
  _ControlledUpdateClient({super.docs, this.beforeWrite});

  final Future<void> Function(int call)? beforeWrite;
  final List<String> started = <String>[];

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) async {
    final int call = started.length;
    started.add(id);
    await beforeWrite?.call(call);
    return super.updateDoc(collection, id, data, sourceTag: sourceTag);
  }
}

class _DocsBatch implements FirestoreBatch, FirestoreTransaction {
  _DocsBatch(this._client);

  final _BatchFirestoreClient _client;

  Map<String, Map<String, dynamic>> _col(String collection) =>
      _client.docs.putIfAbsent(collection, () => <String, Map<String, dynamic>>{});

  @override
  void addDoc(String collection, Map<String, dynamic> data) {
    _col(collection)['auto_${_col(collection).length}'] = Map<String, dynamic>.of(data);
  }

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) {
    final Map<String, dynamic>? existing = _col(collection)[id];
    if (existing == null) {
      throw StateError('NOT_FOUND: $collection/$id');
    }
    existing.addAll(data);
  }

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data, {bool merge = false}) {
    _col(collection)[id] = Map<String, dynamic>.of(data);
  }

  @override
  void deleteDoc(String collection, String id) => _col(collection).remove(id);

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async => _col(collection)[id];
}

void main() {
  final createdAt = DateTime.utc(2026, 1, 2);
  final original = <String, dynamic>{
    'review': false,
    'email': 'uploader@example.com',
    'title': 'Sunset',
    'category': 'Nature',
    'collections': <String>['nature'],
    'wallpaper_thumb': 'https://example.com/t.jpg',
    'createdAt': createdAt,
  };

  late _BatchFirestoreClient client;
  late ReviewBatchBloc bloc;

  setUp(() {
    client = _BatchFirestoreClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        FirebaseCollections.walls: <String, Map<String, dynamic>>{'w1': Map<String, dynamic>.of(original)},
      },
    );
    client.onQuery = (spec) => <FakeDocRow>[
      for (final MapEntry<String, Map<String, dynamic>> e
          in (client.docs[FirebaseCollections.walls] ?? const <String, Map<String, dynamic>>{}).entries)
        if (e.value['review'] == false) (id: e.key, data: Map<String, dynamic>.of(e.value)),
    ];
    bloc = ReviewBatchBloc(ReviewBatchRepository(client), AdminModerationRepository(client));
  });

  tearDown(() => bloc.close());

  Future<void> loaded() async {
    bloc.add(const ReviewBatchLoadRequested());
    await bloc.stream.firstWhere((s) => s.status == ReviewBatchStatus.loaded);
  }

  test('undo of a reject restores the wall and drops the rejection record', () async {
    await loaded();
    bloc.add(const ReviewBatchSwipeRejected(reason: 'no'));
    await bloc.stream.firstWhere((s) => s.currentIndex == 1);

    expect(client.docs[FirebaseCollections.walls], isNot(contains('w1')));
    expect(client.docs[FirebaseCollections.rejectedWalls], contains('w1'));
    final int notificationsAfterReject = client.docs[FirebaseCollections.notifications]?.length ?? 0;

    bloc.add(const ReviewBatchUndoRequested());
    final state = await bloc.stream.firstWhere((s) => s.undoCount == 1);

    expect(state.currentIndex, 0);
    expect(client.docs[FirebaseCollections.walls]!['w1'], original);
    expect(client.docs[FirebaseCollections.rejectedWalls], isNot(contains('w1')));
    expect(client.docs[FirebaseCollections.notifications]?.length ?? 0, notificationsAfterReject);
  });

  test('undo of an approve returns the wall to review without a rejection', () async {
    await loaded();
    bloc.add(const ReviewBatchSwipeApproved());
    await bloc.stream.firstWhere((s) => s.currentIndex == 1);
    expect(client.docs[FirebaseCollections.walls]!['w1']!['review'], isTrue);
    final int notificationsAfterApprove = client.docs[FirebaseCollections.notifications]?.length ?? 0;

    bloc.add(const ReviewBatchUndoRequested());
    final state = await bloc.stream.firstWhere((s) => s.undoCount == 1);

    expect(state.currentIndex, 0);
    expect(client.docs[FirebaseCollections.walls]!['w1']!['review'], isFalse);
    expect(client.docs[FirebaseCollections.walls]!['w1']!['createdAt'], createdAt);
    expect(client.docs[FirebaseCollections.rejectedWalls] ?? const <String, Object?>{}, isEmpty);
    expect(client.docs[FirebaseCollections.notifications]?.length ?? 0, notificationsAfterApprove);
  });

  test('an admin depth pick shows on the card at once and is written to the wall', () async {
    await loaded();

    bloc.add(const ReviewBatchDepthChanged('w1', WallDepthTier.menu));
    final state = await bloc.stream.firstWhere((s) => s.currentWall?.payload['depth'] != null);

    expect(state.currentWall!.payload['depth'], <String, dynamic>{
      'tier': 'menu',
      'by': 'admin',
      'v': 1,
      'kind': null,
      'top': null,
    });
    expect(state.currentIndex, 0);
    await pumpEventQueue();
    final write = client.writes.singleWhere((w) => w.op == 'update');
    expect((write.collection, write.id), (FirebaseCollections.walls, 'w1'));
    expect(write.data, <String, dynamic>{
      'depth': <String, dynamic>{'tier': 'menu', 'by': 'admin', 'v': 1, 'kind': null, 'top': null},
    });
  });

  test('a failed depth write puts the card back and reports the error', () async {
    final rejecting = _RejectingUpdateClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        FirebaseCollections.walls: <String, Map<String, dynamic>>{'w1': Map<String, dynamic>.of(original)},
      },
    );
    rejecting.onQuery = client.onQuery;
    final failing = ReviewBatchBloc(ReviewBatchRepository(rejecting), AdminModerationRepository(rejecting));
    addTearDown(failing.close);
    failing.add(const ReviewBatchLoadRequested());
    await failing.stream.firstWhere((s) => s.status == ReviewBatchStatus.loaded);

    failing.add(const ReviewBatchDepthChanged('w1', WallDepthTier.none));
    final state = await failing.stream.firstWhere((s) => s.status == ReviewBatchStatus.error);

    expect(state.errorMessage, 'Failed to set Depth Effect: Bad state: permission-denied');
    expect(state.currentWall!.payload.containsKey('depth'), isFalse);
  });

  group('depth picks', () {
    Map<String, Map<String, Map<String, dynamic>>> twoWalls() => <String, Map<String, Map<String, dynamic>>>{
      FirebaseCollections.walls: <String, Map<String, dynamic>>{
        'w1': Map<String, dynamic>.of(original),
        'w2': Map<String, dynamic>.of(original),
      },
    };

    Future<ReviewBatchBloc> blocFor(_ControlledUpdateClient controlled) async {
      controlled.onQuery = (spec) => <FakeDocRow>[
        for (final MapEntry<String, Map<String, dynamic>> e
            in (controlled.docs[FirebaseCollections.walls] ?? const <String, Map<String, dynamic>>{}).entries)
          if (e.value['review'] == false) (id: e.key, data: Map<String, dynamic>.of(e.value)),
      ];
      final picking = ReviewBatchBloc(ReviewBatchRepository(controlled), AdminModerationRepository(controlled));
      addTearDown(picking.close);
      picking.add(const ReviewBatchLoadRequested());
      await picking.stream.firstWhere((s) => s.status == ReviewBatchStatus.loaded);
      return picking;
    }

    test('two quick picks on one wall reach the repository in order and the second one stays', () async {
      final Completer<void> firstWrite = Completer<void>();
      final controlled = _ControlledUpdateClient(
        docs: twoWalls(),
        beforeWrite: (call) => call == 0 ? firstWrite.future : Future<void>.value(),
      );
      final picking = await blocFor(controlled);

      picking.add(const ReviewBatchDepthChanged('w1', WallDepthTier.menu));
      picking.add(const ReviewBatchDepthChanged('w1', WallDepthTier.none));
      await pumpEventQueue();
      expect(controlled.started, <String>['w1']);

      firstWrite.complete();
      await pumpEventQueue();

      expect(controlled.started, <String>['w1', 'w1']);
      expect(controlled.writes.map((w) => w.data), <Map<String, dynamic>>[
        <String, dynamic>{
          'depth': <String, dynamic>{'tier': 'menu', 'by': 'admin', 'v': 1, 'kind': null, 'top': null},
        },
        <String, dynamic>{'depth.tier': 'none', 'depth.by': 'admin'},
      ]);
      expect(wallDepthTier(picking.state.walls.first), WallDepthTier.none);
    });

    test('a pick queued for wall A still writes wall A after the admin moved to wall B', () async {
      final Completer<void> firstWrite = Completer<void>();
      final controlled = _ControlledUpdateClient(
        docs: twoWalls(),
        beforeWrite: (call) => call == 0 ? firstWrite.future : Future<void>.value(),
      );
      final picking = await blocFor(controlled);

      picking.add(const ReviewBatchDepthChanged('w1', WallDepthTier.auto));
      picking.add(const ReviewBatchDepthChanged('w1', WallDepthTier.none));
      picking.add(const ReviewBatchSwipeSkipped());
      await pumpEventQueue();
      expect(picking.state.currentWall!.id, 'w2');

      firstWrite.complete();
      await pumpEventQueue();

      expect(controlled.started, <String>['w1', 'w1']);
      expect(wallDepthTier(picking.state.walls[0]), WallDepthTier.none);
      expect(picking.state.walls[1].payload.containsKey('depth'), isFalse);
      expect(picking.state.currentIndex, 1);
    });

    test('a pick for a wall that left the batch writes nothing', () async {
      final controlled = _ControlledUpdateClient(docs: twoWalls());
      final picking = await blocFor(controlled);

      picking.add(const ReviewBatchDepthChanged('gone', WallDepthTier.menu));
      await pumpEventQueue();

      expect(controlled.started, isEmpty);
    });

    test('a pick that works after a failed one returns the status to loaded and clears the message', () async {
      final controlled = _ControlledUpdateClient(
        docs: twoWalls(),
        beforeWrite: (call) => call == 0 ? Future<void>.error(StateError('offline')) : Future<void>.value(),
      );
      final picking = await blocFor(controlled);

      picking.add(const ReviewBatchDepthChanged('w1', WallDepthTier.menu));
      await pumpEventQueue();
      expect(picking.state.status, ReviewBatchStatus.error);
      expect(picking.state.errorMessage, 'Failed to set Depth Effect: Bad state: offline');
      expect(picking.state.walls[1].payload.containsKey('depth'), isFalse);

      picking.add(const ReviewBatchDepthChanged('w2', WallDepthTier.auto));
      await pumpEventQueue();

      expect(picking.state.status, ReviewBatchStatus.loaded);
      expect(picking.state.errorMessage, isNull);
      expect(wallDepthTier(picking.state.walls[0]), isNull);
      expect(wallDepthTier(picking.state.walls[1]), WallDepthTier.auto);
    });
  });

  test('states that differ only in the error message are not equal', () {
    const a = ReviewBatchState(errorMessage: 'one');
    const b = ReviewBatchState(errorMessage: 'two');
    expect(a, isNot(b));
  });
}
