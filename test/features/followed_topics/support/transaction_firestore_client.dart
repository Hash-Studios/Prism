import 'package:Prism/core/firestore/firestore_client.dart';

import '../../../support/fake_firestore_client.dart';

class TransactionFirestoreClient extends FakeFirestoreClient {
  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) async {
    final List<({String op, String collection, String id, Map<String, dynamic>? data, bool merge})> pending =
        <({String op, String collection, String id, Map<String, dynamic>? data, bool merge})>[];
    final T result = await action(_QueuedTransaction(this, pending));
    for (final ({String op, String collection, String id, Map<String, dynamic>? data, bool merge}) write in pending) {
      switch (write.op) {
        case 'set':
          await setDoc(write.collection, write.id, write.data!, merge: write.merge, sourceTag: sourceTag);
        case 'update':
          await updateDoc(write.collection, write.id, write.data!, sourceTag: sourceTag);
        case 'delete':
          await deleteDoc(write.collection, write.id, sourceTag: sourceTag);
      }
    }
    return result;
  }
}

class _QueuedTransaction implements FirestoreTransaction {
  _QueuedTransaction(this.firestore, this.pending);

  final TransactionFirestoreClient firestore;
  final List<({String op, String collection, String id, Map<String, dynamic>? data, bool merge})> pending;

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async => firestore.docs[collection]?[id];

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data, {bool merge = false}) {
    pending.add((op: 'set', collection: collection, id: id, data: data, merge: merge));
  }

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) {
    pending.add((op: 'update', collection: collection, id: id, data: data, merge: true));
  }

  @override
  void deleteDoc(String collection, String id) {
    pending.add((op: 'delete', collection: collection, id: id, data: null, merge: false));
  }
}
