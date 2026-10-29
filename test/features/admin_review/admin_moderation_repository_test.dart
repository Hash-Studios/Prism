import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import 'fake_review_callables.dart';

class _RecordingFirestoreClient extends FakeFirestoreClient {
  final List<FirestoreQuerySpec> watchedQueries = <FirestoreQuerySpec>[];
  _RecordingTransaction? transaction;
  String? transactionSourceTag;
  String? transactionCollection;
  String? transactionDocId;

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) {
    watchedQueries.add(spec);
    return Stream<List<T>>.value(<T>[]);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) {
    transactionSourceTag = sourceTag;
    transactionCollection = collection;
    transactionDocId = docId;
    final _RecordingTransaction recorder = _RecordingTransaction(this);
    transaction = recorder;
    return action(recorder);
  }
}

class _RecordingTransaction implements FirestoreTransaction {
  _RecordingTransaction(this.client);

  final _RecordingFirestoreClient client;
  final List<({String op, String collection, String id, Map<String, dynamic>? data})> writes =
      <({String op, String collection, String id, Map<String, dynamic>? data})>[];

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async => client.docs[collection]?[id];

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data, {bool merge = false}) {
    writes.add((op: 'set', collection: collection, id: id, data: Map<String, dynamic>.of(data)));
    client.docs.putIfAbsent(collection, () => <String, Map<String, dynamic>>{})[id] = Map<String, dynamic>.of(data);
  }

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) {
    writes.add((op: 'update', collection: collection, id: id, data: Map<String, dynamic>.of(data)));
  }

  @override
  void deleteDoc(String collection, String id) {
    writes.add((op: 'delete', collection: collection, id: id, data: null));
    client.docs[collection]?.remove(id);
  }
}

void main() {
  late _RecordingFirestoreClient client;
  late AdminModerationRepository repository;
  late FakeReviewCallables callables;

  setUp(() {
    client = _RecordingFirestoreClient();
    callables = FakeReviewCallables(client.docs);
    repository = AdminModerationRepository.withCaller(client, callables.call);
  });

  test('pending wall stream queries only unreviewed walls by newest first', () async {
    await expectLater(repository.watchPendingWalls(), emits(isEmpty));

    final FirestoreQuerySpec query = client.watchedQueries.single;
    expect(query.collection, FirebaseCollections.walls);
    expect(query.sourceTag, 'admin_review.pending_walls');
    expect(query.isStream, isTrue);
    expect(query.filters, hasLength(1));
    expect(query.filters.single.field, 'review');
    expect(query.filters.single.op, FirestoreFilterOp.isEqualTo);
    expect(query.filters.single.value, isFalse);
    expect(query.orderBy, hasLength(1));
    expect(query.orderBy.single.field, 'createdAt');
    expect(query.orderBy.single.descending, isTrue);
  });

  test('reject moves the wall to rejectedWalls and notifies its creator', () async {
    const FirestoreDocument wall = FirestoreDocument('wall-1', <String, dynamic>{
      'email': 'creator@example.com',
      'wallpaper_thumb': 'https://example.com/wall.jpg',
      'review': false,
    });
    client.docs[FirebaseCollections.walls] = {'wall-1': wall.payload};
    await repository.rejectWall(wall, reason: 'Wrong aspect ratio');

    final request = callables.requests.last;
    expect(request.name, 'rejectWallForReview');
    expect(request.data.keys.toSet(), {
      'wallDocId',
      'expectedWallRevision',
      'expectedReview',
      'rejectionOperationId',
      'reason',
    });
    expect(request.data['expectedReview'], isFalse);
    expect(request.data['reason'], 'Wrong aspect ratio');
    expect(client.transaction, isNull);
    final Map<String, dynamic> rejected = client.docs[FirebaseCollections.rejectedWalls]!['wall-1']!;
    expect(rejected['review'], isFalse);
    expect(rejected['rejectionReason'], 'Wrong aspect ratio');
    expect(rejected['rejectedAt'], isA<DateTime>());
    expect(client.writes.single.op, 'add');
    expect(client.writes.single.collection, FirebaseCollections.notifications);
    expect((client.writes.single.data!['notification'] as Map<String, dynamic>)['body'], 'Wrong aspect ratio');
  });

  test('reject archives current metadata rather than the stale review card', () async {
    const wall = FirestoreDocument('wall-1', <String, dynamic>{
      'review': false,
      'email': 'creator@example.com',
      'title': 'Old title',
      'desc': '',
    });
    client.docs[FirebaseCollections.walls] = {
      'wall-1': {
        ...wall.payload,
        'title': 'Saved just now',
        'desc': 'Fresh description',
        'tags': ['new tag'],
        'category': 'Nature',
      },
    };
    await repository.rejectWall(wall, reason: 'Wrong crop');
    final archive = client.docs[FirebaseCollections.rejectedWalls]!['wall-1']!;
    expect(archive['title'], 'Saved just now');
    expect(archive['desc'], 'Fresh description');
    expect(archive['tags'], ['new tag']);
    expect(archive['category'], 'Nature');
  });

  test('reject refuses an approval race or disappeared wall with no writes', () async {
    const wall = FirestoreDocument('wall-1', <String, dynamic>{'review': false});
    client.docs[FirebaseCollections.walls] = {
      'wall-1': {'review': true},
    };
    await expectLater(repository.rejectWall(wall, reason: 'no'), throwsA(isA<Exception>()));
    expect(client.transaction, isNull);
    client.docs[FirebaseCollections.walls]!.clear();
    await expectLater(repository.rejectWall(wall, reason: 'no'), throwsStateError);
    expect(client.transaction, isNull);
    expect(client.writes, isEmpty);
  });

  test('undo rejection restores the fresh archived metadata and removes rejection-only fields', () async {
    const wall = FirestoreDocument('wall-1', <String, dynamic>{'review': false, 'title': 'Old'});
    client.docs[FirebaseCollections.walls] = {
      'wall-1': {...wall.payload, 'title': 'New'},
    };
    await repository.rejectWall(wall, reason: 'no');
    await repository.undoRejectWall(wall);
    expect(client.docs[FirebaseCollections.walls]!['wall-1'], {'review': false, 'title': 'New'});
    expect(client.docs[FirebaseCollections.rejectedWalls], isNot(contains('wall-1')));
  });

  test('undo never overwrites a live wall or a replacement rejection archive', () async {
    const wall = FirestoreDocument('wall-1', <String, dynamic>{'review': false});
    client.docs[FirebaseCollections.walls] = {'wall-1': wall.payload};
    await repository.rejectWall(wall, reason: 'no');
    client.docs[FirebaseCollections.walls]!['wall-1'] = {'review': false, 'title': 'New incarnation'};
    await expectLater(repository.undoRejectWall(wall), throwsStateError);
    expect(client.transaction, isNull);
    client.docs[FirebaseCollections.walls]!.clear();
    client.docs[FirebaseCollections.rejectedWalls]!['wall-1']!['rejectionOperationId'] = 'another-rejection';
    await expectLater(repository.undoRejectWall(wall), throwsStateError);
    expect(client.transaction, isNull);
  });

  test('undo refuses a verified child admission without calling the undo endpoint', () async {
    const wall = FirestoreDocument('wall-1', <String, dynamic>{'review': false});
    client.docs[FirebaseCollections.walls] = {'wall-1': wall.payload};
    await repository.rejectWall(wall, reason: 'no');
    callables.admittedParents.add('wall-1');
    await expectLater(repository.undoRejectWall(wall), throwsStateError);
    expect(callables.requests.where((r) => r.name == 'undoWallRejection'), isEmpty);
    expect(client.docs[FirebaseCollections.rejectedWalls], contains('wall-1'));
  });

  test('lost rejection response replays the same operation before reading now-deleted live wall', () async {
    const wall = FirestoreDocument('wall-1', <String, dynamic>{'review': false});
    client.docs[FirebaseCollections.walls] = {'wall-1': wall.payload};
    callables.loseNextRejectResponse = true;
    await expectLater(repository.rejectWall(wall, reason: 'no'), throwsA(isA<Exception>()));
    await repository.rejectWall(wall, reason: 'no');
    final rejects = callables.requests.where((r) => r.name == 'rejectWallForReview').toList();
    expect(rejects, hasLength(2));
    expect(rejects.first.data, rejects.last.data);
    expect(callables.requests.where((r) => r.name == 'getWallResubmissionContext'), hasLength(1));
  });

  test('a confirmed rejection cannot replay its old operation against a recreated wall', () async {
    const wall = FirestoreDocument('wall-1', <String, dynamic>{'review': false});
    client.docs[FirebaseCollections.walls] = {'wall-1': wall.payload};
    await repository.rejectWall(wall, reason: 'no');
    // Another authorized session restores the wall; this repository has not run undo.
    client.docs[FirebaseCollections.rejectedWalls]!.clear();
    client.docs[FirebaseCollections.walls]!['wall-1'] = {...wall.payload, 'title': 'Restored'};
    await repository.rejectWall(wall, reason: 'no');
    final rejects = callables.requests.where((r) => r.name == 'rejectWallForReview').toList();
    expect(rejects.last.data['rejectionOperationId'], isNot(rejects.first.data['rejectionOperationId']));
    expect(client.docs[FirebaseCollections.walls], isNot(contains('wall-1')));
    expect(client.docs[FirebaseCollections.rejectedWalls]!['wall-1']!['title'], 'Restored');
  });

  test('approval updates the wall and leaves the inbox entry to onWallApproved', () async {
    const wall = FirestoreDocument('wall-1', <String, dynamic>{'email': 'creator@example.com', 'review': false});

    await repository.approveWall(wall);

    final write = client.writes.single;
    expect((write.op, write.collection, write.id), ('update', FirebaseCollections.walls, 'wall-1'));
    expect(write.data!['review'], isTrue);
    expect(write.data!['collections'], <String>['community']);
  });

  test('approval replaces creator-written collections and removes the streak fields', () async {
    const wall = FirestoreDocument('wall-2', <String, dynamic>{
      'email': 'creator@example.com',
      'review': false,
      'collections': <String>['streak', 'wall_of_the_day'],
      'is_streak_exclusive': true,
      'streak_shop_coin_cost': 1,
    });

    await repository.approveWall(wall);

    final data = client.writes.single.data!;
    expect(data['collections'], <String>['community']);
    expect(data['is_streak_exclusive'], isA<FieldValue>());
    expect(data['streak_shop_coin_cost'], isA<FieldValue>());
  });

  test('approval keeps values the admin sets on purpose', () async {
    const wall = FirestoreDocument('wall-3', <String, dynamic>{'email': 'creator@example.com', 'review': false});

    await repository.approveWall(
      wall,
      collections: <String>['community', 'minimal'],
      streakExclusive: true,
      streakShopCoinCost: 50,
    );

    final data = client.writes.single.data!;
    expect(data['collections'], <String>['community', 'minimal']);
    expect(data['is_streak_exclusive'], isTrue);
    expect(data['streak_shop_coin_cost'], 50);
  });

  test('undoing an approval puts the original streak values back', () async {
    const wall = FirestoreDocument('wall-4', <String, dynamic>{
      'review': false,
      'collections': <String>['community'],
      'is_streak_exclusive': true,
      'streak_shop_coin_cost': 20,
    });

    await repository.undoApproveWall(wall);

    final data = client.writes.single.data!;
    expect(data['review'], isFalse);
    expect(data['is_streak_exclusive'], isTrue);
    expect(data['streak_shop_coin_cost'], 20);
  });

  group('depth override', () {
    test('changes only the tier and the author when the detector already wrote a depth map', () async {
      const wall = FirestoreDocument('wall-5', <String, dynamic>{
        'review': false,
        'depth': <String, dynamic>{'tier': 'none', 'kind': 'sky', 'top': 0.4, 'v': 1, 'by': 'detector'},
      });

      await repository.setDepthTier(wall, WallDepthTier.menu);

      final write = client.writes.single;
      expect((write.op, write.collection, write.id), ('update', FirebaseCollections.walls, 'wall-5'));
      expect(write.data, <String, dynamic>{'depth.tier': 'menu', 'depth.by': 'admin'});
    });

    test('writes a whole depth map for a wall that was never checked', () async {
      const wall = FirestoreDocument('wall-6', <String, dynamic>{'review': false});

      await repository.setDepthTier(wall, WallDepthTier.auto);

      expect(client.writes.single.data, <String, dynamic>{
        'depth': <String, dynamic>{'tier': 'auto', 'by': 'admin', 'v': 1, 'kind': null, 'top': null},
      });
    });
  });

  test('requestText reads the text of the linked request and refuses bad ids', () async {
    final FakeFirestoreClient client = FakeFirestoreClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        'wallRequests': <String, Map<String, dynamic>>{
          'r1': <String, dynamic>{'text': 'lofi capybara astronaut', 'requesterUid': 'u1'},
        },
      },
    );
    final AdminModerationRepository repository = AdminModerationRepository(client);
    expect(await repository.requestText('r1'), 'lofi capybara astronaut');
    expect(await repository.requestText('missing'), isNull);
    expect(await repository.requestText(''), isNull);
    expect(await repository.requestText('a/b'), isNull);
  });
}
