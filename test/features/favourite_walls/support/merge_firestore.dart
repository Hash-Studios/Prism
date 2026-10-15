import 'package:Prism/core/firestore/firestore_client.dart';

import '../../../support/fake_firestore_client.dart';

class RecordingBatch implements FirestoreBatch {
  final List<({String collection, String id, Map<String, dynamic> data})> sets = [];

  @override
  void addDoc(String collection, Map<String, dynamic> data) => throw UnimplementedError();

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data) =>
      sets.add((collection: collection, id: id, data: data));

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) => throw UnimplementedError();

  @override
  void deleteDoc(String collection, String id) => throw UnimplementedError();
}

/// A fake Firestore that records batches, for the guest merge.
class MergeFirestore extends FakeFirestoreClient {
  MergeFirestore({super.onQuery});

  final List<RecordingBatch> batches = <RecordingBatch>[];
  final List<String> batchTags = <String>[];
  Object? batchError;

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) async {
    final RecordingBatch batch = RecordingBatch();
    await action(batch);
    final Object? error = batchError;
    if (error != null) throw error;
    batches.add(batch);
    batchTags.add(sourceTag);
  }
}
