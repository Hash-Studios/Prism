import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

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
    final _RecordingTransaction recorder = _RecordingTransaction();
    transaction = recorder;
    return action(recorder);
  }
}

class _RecordingTransaction implements FirestoreTransaction {
  final List<({String op, String collection, String id, Map<String, dynamic>? data})> writes =
      <({String op, String collection, String id, Map<String, dynamic>? data})>[];

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async => null;

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data, {bool merge = false}) {
    writes.add((op: 'set', collection: collection, id: id, data: Map<String, dynamic>.of(data)));
  }

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) {
    writes.add((op: 'update', collection: collection, id: id, data: Map<String, dynamic>.of(data)));
  }

  @override
  void deleteDoc(String collection, String id) =>
      writes.add((op: 'delete', collection: collection, id: id, data: null));
}

void main() {
  late _RecordingFirestoreClient client;
  late AdminModerationRepository repository;

  setUp(() {
    client = _RecordingFirestoreClient();
    repository = AdminModerationRepository(client);
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
    await repository.rejectWall(wall, reason: 'Wrong aspect ratio');

    expect(client.transactionSourceTag, 'admin_review.reject_wall');
    expect(client.transactionCollection, FirebaseCollections.walls);
    expect(client.transactionDocId, 'wall-1');
    expect(
      client.transaction!.writes.map((write) => (write.op, write.collection, write.id)),
      <(String, String, String)>[
        ('set', FirebaseCollections.rejectedWalls, 'wall-1'),
        ('delete', FirebaseCollections.walls, 'wall-1'),
      ],
    );
    final Map<String, dynamic> rejected = client.transaction!.writes.first.data!;
    expect(rejected['review'], isFalse);
    expect(rejected['rejectionReason'], 'Wrong aspect ratio');
    expect(rejected['rejectedAt'], isA<DateTime>());
    expect(client.writes.single.op, 'add');
    expect(client.writes.single.collection, FirebaseCollections.notifications);
    expect((client.writes.single.data!['notification'] as Map<String, dynamic>)['body'], 'Wrong aspect ratio');
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
