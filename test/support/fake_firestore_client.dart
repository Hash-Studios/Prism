import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:flutter_test/flutter_test.dart';

typedef FakeDocRow = ({String id, Map<String, dynamic> data});

/// In-memory [FirestoreClient] for repository tests.
///
/// `docs[collection][id]` backs `getById` and the write methods. `onQuery`
/// answers `query`; every spec is recorded in [querySpecs]. Methods a test
/// does not configure throw through [Fake].
class FakeFirestoreClient extends Fake implements FirestoreClient {
  FakeFirestoreClient({Map<String, Map<String, Map<String, dynamic>>>? docs, this.onQuery})
    : docs = docs ?? <String, Map<String, Map<String, dynamic>>>{};

  final Map<String, Map<String, Map<String, dynamic>>> docs;
  List<FakeDocRow> Function(FirestoreQuerySpec spec)? onQuery;
  Object? queryError;
  final List<FirestoreQuerySpec> querySpecs = <FirestoreQuerySpec>[];
  final List<({String op, String collection, String id, Map<String, dynamic>? data})> writes =
      <({String op, String collection, String id, Map<String, dynamic>? data})>[];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    querySpecs.add(spec);
    final Object? error = queryError;
    if (error != null) throw error;
    final List<FakeDocRow> rows = onQuery?.call(spec) ?? const <FakeDocRow>[];
    return rows.map((row) => map(row.data, row.id)).toList(growable: false);
  }

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    final Map<String, dynamic>? data = docs[collection]?[id];
    return data == null ? null : map(data, id);
  }

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async {
    writes.add((op: 'set', collection: collection, id: id, data: data));
    final Map<String, Map<String, dynamic>> col = docs.putIfAbsent(collection, () => <String, Map<String, dynamic>>{});
    col[id] = merge ? <String, dynamic>{...?col[id], ...data} : Map<String, dynamic>.of(data);
  }

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) async {
    writes.add((op: 'update', collection: collection, id: id, data: data));
    final Map<String, Map<String, dynamic>> col = docs.putIfAbsent(collection, () => <String, Map<String, dynamic>>{});
    col[id] = <String, dynamic>{...?col[id], ...data};
  }

  @override
  Future<void> deleteDoc(String collection, String id, {required String sourceTag}) async {
    writes.add((op: 'delete', collection: collection, id: id, data: null));
    docs[collection]?.remove(id);
  }

  @override
  Future<String> addDoc(String collection, Map<String, dynamic> data, {required String sourceTag}) async {
    final Map<String, Map<String, dynamic>> col = docs.putIfAbsent(collection, () => <String, Map<String, dynamic>>{});
    final String id = 'auto_${col.length}';
    writes.add((op: 'add', collection: collection, id: id, data: data));
    col[id] = Map<String, dynamic>.of(data);
    return id;
  }
}
