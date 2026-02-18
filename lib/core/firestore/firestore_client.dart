import 'package:Prism/core/firestore/firestore_query_specs.dart';

abstract class FirestoreTransaction {
  Future<Map<String, dynamic>?> getDoc(String collection, String id);

  void setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  });

  void updateDoc(
    String collection,
    String id,
    Map<String, dynamic> data,
  );

  void deleteDoc(String collection, String id);
}

abstract class FirestoreClient {
  Future<List<T>> query<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  );

  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
  });

  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  });

  Future<void> updateDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    required String sourceTag,
  });

  Future<void> deleteDoc(
    String collection,
    String id, {
    required String sourceTag,
  });

  Future<String> addDoc(
    String collection,
    Map<String, dynamic> data, {
    required String sourceTag,
  });

  Stream<List<T>> watchQuery<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  );

  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  });
}
