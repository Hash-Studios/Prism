import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/features/admin_review/biz/bloc/review_batch_bloc.dart';
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

  test('states that differ only in the error message are not equal', () {
    const a = ReviewBatchState(errorMessage: 'one');
    const b = ReviewBatchState(errorMessage: 'two');
    expect(a, isNot(b));
  });
}
