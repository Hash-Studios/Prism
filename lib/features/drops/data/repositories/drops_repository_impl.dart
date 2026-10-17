import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_server_read.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/drops/data/drop_mapper.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/domain/repositories/drops_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DropsRepository)
class DropsRepositoryImpl implements DropsRepository {
  DropsRepositoryImpl(
    this._firestoreClient, {
    @ignoreParam DurableJsonStore? store,
    @ignoreParam Duration readTimeout = _sdkReadTimeout,
  }) : _store = store ?? DurableJsonStore('drop_read_snapshots'),
       _readTimeout = readTimeout;

  final FirestoreClient _firestoreClient;
  final DurableJsonStore _store;
  final Duration _readTimeout;
  Future<void> _snapshotTail = Future<void>.value();

  static const Duration _sdkReadTimeout = Duration(seconds: 5);
  static const String _snapshotKey = 'recent';
  static const int _maxRecentWeeks = 8;

  @override
  Future<Result<DropEntity?>> fetchLive(DateTime now) async {
    try {
      final List<DropEntity?> rows = await _firestoreClient
          .queryFromServer<DropEntity?>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.drops,
              sourceTag: 'drops.live',
              filters: <FirestoreFilter>[
                FirestoreFilter(
                  field: 'endsAt',
                  op: FirestoreFilterOp.isGreaterThan,
                  value: now.millisecondsSinceEpoch,
                ),
              ],
              orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'endsAt')],
              limit: 1,
            ),
            (data, docId) => dropFromMap(data, docId),
            timeout: _readTimeout,
          )
          .timeout(_readTimeout);
      final DropEntity? drop = rows.nonNulls.firstOrNull;
      final DropEntity? live = drop != null && drop.isLiveAt(now) ? drop : null;
      try {
        await _rememberLive(drop, now);
      } on Object {}
      return Result.success(live);
    } catch (error, stackTrace) {
      logger.e('[DropsRepository] fetchLive failed', error: error, stackTrace: stackTrace);
      try {
        final List<DropEntity> saved = await _readRecent();
        final DropEntity? live = saved.where((DropEntity drop) => drop.isLiveAt(now)).firstOrNull;
        if (_isTransient(error) && live != null) return Result.success(live);
      } on Object {}
      if (_isPermissionDenied(error)) {
        try {
          await _store.delete(_snapshotKey);
        } on Object {}
      }
      return Result.error(const ServerFailure("Couldn't load this week's Drop. Check your connection and try again."));
    }
  }

  @override
  Future<Result<DropEntity?>> fetchByWeekKey(String weekKey) async {
    try {
      final DropEntity? drop = await _firestoreClient
          .getFromServer<DropEntity?>(
            FirebaseCollections.drops,
            weekKey,
            (data, docId) => dropFromMap(data, docId),
            sourceTag: 'drops.byWeek',
            timeout: _readTimeout,
          )
          .timeout(_readTimeout);
      try {
        await _remember(drop, weekKey);
      } on Object {}
      return Result.success(drop);
    } catch (error, stackTrace) {
      logger.e('[DropsRepository] fetchByWeekKey failed', error: error, stackTrace: stackTrace);
      try {
        final DropEntity? saved = (await _readRecent()).where((DropEntity drop) => drop.weekKey == weekKey).firstOrNull;
        if (_isTransient(error) && saved != null) return Result.success(saved);
      } on Object {}
      if (_isPermissionDenied(error)) {
        try {
          await _remember(null, weekKey);
        } on Object {}
      }
      return Result.error(const ServerFailure("Couldn't load this Drop. Check your connection and try again."));
    }
  }

  Future<void> _remember(DropEntity? drop, String? weekKey) => _serializeSnapshot(() async {
    final List<DropEntity> recent = await _readRecent();
    if (weekKey != null) {
      recent.removeWhere((DropEntity item) => item.weekKey == weekKey);
    }
    if (drop != null) recent.insert(0, drop);
    await _store.write(_snapshotKey, <String, Object?>{
      'drops': recent.take(_maxRecentWeeks).map(_toMap).toList(growable: false),
    });
  });

  Future<void> _rememberLive(DropEntity? drop, DateTime now) => _serializeSnapshot(() async {
    final List<DropEntity> recent = await _readRecent()
      ..removeWhere((DropEntity item) => item.endsAt.isAfter(now));
    if (drop != null) recent.insert(0, drop);
    await _store.write(_snapshotKey, <String, Object?>{
      'drops': recent.take(_maxRecentWeeks).map(_toMap).toList(growable: false),
    });
  });

  Future<void> _serializeSnapshot(Future<void> Function() operation) {
    final Future<void> result = _snapshotTail.then((_) => operation());
    _snapshotTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<DropEntity>> _readRecent() async {
    final Object? raw = (await _store.read(_snapshotKey))?['drops'];
    if (raw is! List) return <DropEntity>[];
    final List<DropEntity> recent = <DropEntity>[];
    for (final Object? item in raw) {
      if (item is! Map) continue;
      try {
        recent.add(_fromMap(Map<String, Object?>.from(item)));
      } on Object {
        continue;
      }
      if (recent.length == _maxRecentWeeks) break;
    }
    return recent;
  }

  static Map<String, Object?> _toMap(DropEntity drop) => <String, Object?>{
    'weekKey': drop.weekKey,
    'title': drop.title,
    'startsAt': drop.startsAt.millisecondsSinceEpoch,
    'endsAt': drop.endsAt.millisecondsSinceEpoch,
    'priceWall': drop.priceWall,
    'pricePack': drop.pricePack,
    'count': drop.count,
    'walls': drop.walls
        .map(
          (DropWall wall) => <String, Object?>{
            'id': wall.id,
            'title': wall.title,
            'thumb': wall.thumb,
            'resolution': wall.resolution,
            'by': wall.by,
            'seriesId': wall.seriesId,
          },
        )
        .toList(growable: false),
  };

  static DropEntity _fromMap(Map<String, Object?> data) =>
      dropFromMap(data.cast<String, dynamic>(), data['weekKey'] as String)!;

  static bool _isTransient(Object error) =>
      error is TimeoutException ||
      const <String>{
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
        'internal',
        'resource-exhausted',
      }.contains(error is FirestoreError ? error.code : null);

  static bool _isPermissionDenied(Object error) => error is FirestoreError && error.code == 'permission-denied';
}
