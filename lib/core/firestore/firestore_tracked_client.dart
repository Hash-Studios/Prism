import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _RawQueryDoc {
  const _RawQueryDoc(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

class _QueryCacheEntry {
  const _QueryCacheEntry(this.docs, this.cachedAt);

  final List<_RawQueryDoc> docs;
  final DateTime cachedAt;
}

class FirestoreTrackedClient implements FirestoreClient {
  FirestoreTrackedClient(this._firestore, this._telemetry);

  final FirebaseFirestore _firestore;
  final FirestoreTelemetrySink _telemetry;
  final Map<String, Future<_QueryCacheEntry>> _inflightQueries = <String, Future<_QueryCacheEntry>>{};
  final Map<String, _QueryCacheEntry> _queryCache = <String, _QueryCacheEntry>{};
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _cursorDocCache =
      <String, DocumentSnapshot<Map<String, dynamic>>>{};

  static const int _defaultCacheWindowMs = 30000;
  static const int _maxQueryCacheEntries = 200;
  static const int _maxCursorDocCacheEntries = 600;

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

  String _queryKey(FirestoreQuerySpec spec) => spec.filtersHash;

  String _cursorDocKey(String collection, String docId) => '$collection::$docId';

  int _cacheWindowMs(FirestoreQuerySpec spec) {
    if (spec.dedupeWindowMs > 0) {
      return spec.dedupeWindowMs;
    }
    switch (spec.cachePolicy) {
      case FirestoreCachePolicy.networkOnly:
        return 0;
      case FirestoreCachePolicy.staleWhileRevalidate:
      case FirestoreCachePolicy.memoryFirst:
        return _defaultCacheWindowMs;
    }
  }

  bool _canUseCache(FirestoreQuerySpec spec) {
    return spec.cachePolicy != FirestoreCachePolicy.networkOnly || spec.dedupeWindowMs > 0;
  }

  bool _isCacheFresh(_QueryCacheEntry entry, FirestoreQuerySpec spec) {
    final int ttlMs = _cacheWindowMs(spec);
    if (ttlMs <= 0) {
      return false;
    }
    return DateTime.now().difference(entry.cachedAt).inMilliseconds <= ttlMs;
  }

  void _saveQueryCache(String key, _QueryCacheEntry entry) {
    _queryCache[key] = entry;
    while (_queryCache.length > _maxQueryCacheEntries) {
      _queryCache.remove(_queryCache.keys.first);
    }
  }

  void _cacheCursorDoc(DocumentSnapshot<Map<String, dynamic>> doc, String collection) {
    if (!doc.exists) {
      return;
    }
    _cursorDocCache[_cursorDocKey(collection, doc.id)] = doc;
    while (_cursorDocCache.length > _maxCursorDocCacheEntries) {
      _cursorDocCache.remove(_cursorDocCache.keys.first);
    }
  }

  List<T> _mapCachedDocs<T>(_QueryCacheEntry cached, T Function(Map<String, dynamic> data, String docId) map) {
    return cached.docs.map((doc) => map(Map<String, dynamic>.from(doc.data), doc.id)).toList(growable: false);
  }

  Future<Query<Map<String, dynamic>>> _applyCursorIfRequired(
    Query<Map<String, dynamic>> query,
    FirestoreQuerySpec spec,
  ) async {
    final String? startAfterDocId = spec.startAfterDocId;
    if (startAfterDocId == null || startAfterDocId.isEmpty) {
      return query;
    }
    final String key = _cursorDocKey(spec.collection, startAfterDocId);
    final DocumentSnapshot<Map<String, dynamic>>? cachedDoc = _cursorDocCache[key];
    if (cachedDoc != null) {
      return query.startAfterDocument(cachedDoc);
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection(spec.collection)
        .doc(startAfterDocId)
        .get();
    if (doc.exists) {
      _cacheCursorDoc(doc, spec.collection);
      return query.startAfterDocument(doc);
    }
    return query;
  }

  Future<_QueryCacheEntry> _executeNetworkQuery(FirestoreQuerySpec spec) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      Query<Map<String, dynamic>> query = _applySpec(spec);
      query = await _applyCursorIfRequired(query, spec);
      final QuerySnapshot<Map<String, dynamic>> result = await query.get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in result.docs) {
        _cacheCursorDoc(doc, spec.collection);
      }
      final _QueryCacheEntry cached = _QueryCacheEntry(
        result.docs.map((doc) => _RawQueryDoc(doc.id, Map<String, dynamic>.from(doc.data()))).toList(growable: false),
        DateTime.now(),
      );
      if (_canUseCache(spec)) {
        _saveQueryCache(_queryKey(spec), cached);
      }
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
      return cached;
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

  void _refreshInBackground(FirestoreQuerySpec spec) {
    final String key = _queryKey(spec);
    if (_inflightQueries.containsKey(key)) {
      return;
    }
    final Future<_QueryCacheEntry> refresh = _executeNetworkQuery(spec);
    _inflightQueries[key] = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (identical(_inflightQueries[key], refresh)) {
          _inflightQueries.remove(key);
        }
      }),
    );
  }

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    final String key = _queryKey(spec);
    final _QueryCacheEntry? cached = _queryCache[key];
    if (_canUseCache(spec) && cached != null && _isCacheFresh(cached, spec)) {
      if (spec.cachePolicy == FirestoreCachePolicy.staleWhileRevalidate) {
        _refreshInBackground(spec);
      }
      return _mapCachedDocs(cached, map);
    }
    final Future<_QueryCacheEntry>? inflight = _inflightQueries[key];
    if (inflight != null) {
      final _QueryCacheEntry shared = await inflight;
      return _mapCachedDocs(shared, map);
    }
    final Future<_QueryCacheEntry> request = _executeNetworkQuery(spec);
    _inflightQueries[key] = request;
    try {
      final _QueryCacheEntry resolved = await request;
      return _mapCachedDocs(resolved, map);
    } finally {
      if (identical(_inflightQueries[key], request)) {
        _inflightQueries.remove(key);
      }
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
  Future<String> addDoc(String collection, Map<String, dynamic> data, {required String sourceTag}) async {
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
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) async {
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
  Future<void> deleteDoc(String collection, String id, {required String sourceTag}) async {
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
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) {
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
    return query
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => map(doc.data(), doc.id)).toList(growable: false);
        })
        .handleError((Object error) async {
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
