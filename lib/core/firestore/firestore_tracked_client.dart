import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTrackedClient implements FirestoreClient {
  FirestoreTrackedClient(
    this._firestore,
    this._telemetry,
  );

  final FirebaseFirestore _firestore;
  final FirestoreTelemetrySink _telemetry;

  Query<Map<String, dynamic>> _applySpec(FirestoreQuerySpec spec) {
    Query<Map<String, dynamic>> query = _firestore.collection(spec.collection);
    for (final FirestoreFilter filter in spec.filters) {
      switch (filter.op) {
        case FirestoreFilterOp.isEqualTo:
          query = query.where(filter.field, isEqualTo: filter.value);
        case FirestoreFilterOp.isNotEqualTo:
          query = query.where(filter.field, isNotEqualTo: filter.value);
        case FirestoreFilterOp.isLessThan:
          query = query.where(filter.field, isLessThan: filter.value);
        case FirestoreFilterOp.isLessThanOrEqualTo:
          query = query.where(filter.field, isLessThanOrEqualTo: filter.value);
        case FirestoreFilterOp.isGreaterThan:
          query = query.where(filter.field, isGreaterThan: filter.value);
        case FirestoreFilterOp.isGreaterThanOrEqualTo:
          query = query.where(filter.field, isGreaterThanOrEqualTo: filter.value);
        case FirestoreFilterOp.arrayContains:
          query = query.where(filter.field, arrayContains: filter.value);
        case FirestoreFilterOp.arrayContainsAny:
          query = query.where(filter.field, arrayContainsAny: filter.value as List<Object?>?);
        case FirestoreFilterOp.whereIn:
          query = query.where(filter.field, whereIn: filter.value as List<Object?>?);
        case FirestoreFilterOp.whereNotIn:
          query = query.where(filter.field, whereNotIn: filter.value as List<Object?>?);
        case FirestoreFilterOp.isNull:
          query = query.where(filter.field, isNull: filter.value as bool? ?? true);
      }
    }
    for (final FirestoreOrderBy order in spec.orderBy) {
      query = query.orderBy(order.field, descending: order.descending);
    }
    if (spec.startAfterFieldValues != null && spec.startAfterFieldValues!.isNotEmpty) {
      query = query.startAfter(spec.startAfterFieldValues!);
    }
    if (spec.limit != null) {
      query = query.limit(spec.limit!);
    }
    return query;
  }

  List<String> _orderByList(FirestoreQuerySpec spec) =>
      spec.orderBy.map((e) => '${e.field}:${e.descending ? 'desc' : 'asc'}').toList(growable: false);

  Future<void> _emitTelemetry(FirestoreTelemetryEvent event) async {
    unawaited(_telemetry.emit(event));
  }

  @override
  Future<List<T>> query<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      Query<Map<String, dynamic>> query = _applySpec(spec);
      if (spec.startAfterDocId != null && spec.startAfterDocId!.isNotEmpty) {
        final doc = await _firestore.collection(spec.collection).doc(spec.startAfterDocId).get();
        if (doc.exists) {
          query = query.startAfterDocument(doc);
        }
      }
      final QuerySnapshot<Map<String, dynamic>> result = await query.get();
      final List<T> output = result.docs.map((e) => map(e.data(), e.id)).toList(growable: false);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: spec.sourceTag,
          operation: FirestoreOperation.queryGet,
          collection: spec.collection,
          filtersHash: spec.filtersHash,
          orderBy: _orderByList(spec),
          limit: spec.limit,
          durationMs: sw.elapsedMilliseconds,
          resultCount: result.docs.length,
          success: true,
        ),
      );
      return output;
    } catch (error) {
      final FirestoreError mapped = mapFirestoreError(error);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: spec.sourceTag,
          operation: FirestoreOperation.queryGet,
          collection: spec.collection,
          filtersHash: spec.filtersHash,
          orderBy: _orderByList(spec),
          limit: spec.limit,
          durationMs: sw.elapsedMilliseconds,
          success: false,
          errorCode: mapped.code,
        ),
      );
      throw mapped;
    }
  }

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore.collection(collection).doc(id).get();
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.docGet,
          collection: collection,
          filtersHash: '$collection:$id',
          durationMs: sw.elapsedMilliseconds,
          resultCount: doc.exists ? 1 : 0,
          docId: id,
          success: true,
        ),
      );
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return map(doc.data()!, doc.id);
    } catch (error) {
      final FirestoreError mapped = mapFirestoreError(error);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.docGet,
          collection: collection,
          filtersHash: '$collection:$id',
          durationMs: sw.elapsedMilliseconds,
          docId: id,
          success: false,
          errorCode: mapped.code,
        ),
      );
      throw mapped;
    }
  }

  @override
  Future<String> addDoc(
    String collection,
    Map<String, dynamic> data, {
    required String sourceTag,
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      final ref = await _firestore.collection(collection).add(data);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.add,
          collection: collection,
          filtersHash: collection,
          durationMs: sw.elapsedMilliseconds,
          docId: ref.id,
          success: true,
        ),
      );
      return ref.id;
    } catch (error) {
      final FirestoreError mapped = mapFirestoreError(error);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.add,
          collection: collection,
          filtersHash: collection,
          durationMs: sw.elapsedMilliseconds,
          success: false,
          errorCode: mapped.code,
        ),
      );
      throw mapped;
    }
  }

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      await _firestore.collection(collection).doc(id).set(data, SetOptions(merge: merge));
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.set,
          collection: collection,
          filtersHash: '$collection:$id',
          durationMs: sw.elapsedMilliseconds,
          docId: id,
          success: true,
        ),
      );
    } catch (error) {
      final FirestoreError mapped = mapFirestoreError(error);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.set,
          collection: collection,
          filtersHash: '$collection:$id',
          durationMs: sw.elapsedMilliseconds,
          docId: id,
          success: false,
          errorCode: mapped.code,
        ),
      );
      throw mapped;
    }
  }

  @override
  Future<void> updateDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    required String sourceTag,
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      await _firestore.collection(collection).doc(id).update(data);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.update,
          collection: collection,
          filtersHash: '$collection:$id',
          durationMs: sw.elapsedMilliseconds,
          docId: id,
          success: true,
        ),
      );
    } catch (error) {
      final FirestoreError mapped = mapFirestoreError(error);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.update,
          collection: collection,
          filtersHash: '$collection:$id',
          durationMs: sw.elapsedMilliseconds,
          docId: id,
          success: false,
          errorCode: mapped.code,
        ),
      );
      throw mapped;
    }
  }

  @override
  Future<void> deleteDoc(
    String collection,
    String id, {
    required String sourceTag,
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      await _firestore.collection(collection).doc(id).delete();
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.delete,
          collection: collection,
          filtersHash: '$collection:$id',
          durationMs: sw.elapsedMilliseconds,
          docId: id,
          success: true,
        ),
      );
    } catch (error) {
      final FirestoreError mapped = mapFirestoreError(error);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: sourceTag,
          operation: FirestoreOperation.delete,
          collection: collection,
          filtersHash: '$collection:$id',
          durationMs: sw.elapsedMilliseconds,
          docId: id,
          success: false,
          errorCode: mapped.code,
        ),
      );
      throw mapped;
    }
  }

  @override
  Stream<List<T>> watchQuery<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) {
    final Query<Map<String, dynamic>> query = _applySpec(spec);
    final DateTime start = DateTime.now();
    unawaited(
      _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: start,
          sourceTag: spec.sourceTag,
          operation: FirestoreOperation.streamSubscribe,
          collection: spec.collection,
          filtersHash: spec.filtersHash,
          orderBy: _orderByList(spec),
          limit: spec.limit,
          durationMs: 0,
          success: true,
        ),
      ),
    );
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => map(doc.data(), doc.id)).toList(growable: false);
    }).handleError((Object error) async {
      final FirestoreError mapped = mapFirestoreError(error);
      await _emitTelemetry(
        FirestoreTelemetryEvent(
          timestamp: DateTime.now(),
          sourceTag: spec.sourceTag,
          operation: FirestoreOperation.streamSubscribe,
          collection: spec.collection,
          filtersHash: spec.filtersHash,
          orderBy: _orderByList(spec),
          limit: spec.limit,
          durationMs: DateTime.now().difference(start).inMilliseconds,
          success: false,
          errorCode: mapped.code,
        ),
      );
      throw mapped;
    });
  }
}
