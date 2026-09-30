import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
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
}
