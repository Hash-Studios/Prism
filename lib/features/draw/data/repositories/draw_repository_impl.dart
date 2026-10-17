import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_server_read.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';
import 'package:Prism/features/draw/domain/repositories/draw_repository.dart';
import 'package:Prism/features/leaderboard/domain/week_key.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DrawRepository)
class DrawRepositoryImpl implements DrawRepository {
  DrawRepositoryImpl(
    this._firestoreClient, {
    @ignoreParam DurableJsonStore? store,
    @ignoreParam Duration readTimeout = _sdkReadTimeout,
  }) : _store = store ?? DurableJsonStore('draw_read_snapshots'),
       _readTimeout = readTimeout;

  final FirestoreClient _firestoreClient;
  final DurableJsonStore _store;
  final Duration _readTimeout;

  static const String _defaultItemId = 'frame_prism';
  static const Duration _sdkReadTimeout = Duration(seconds: 5);
  static const String _currentKey = 'current';
  static const String _settledKey = 'settled';
  static final Map<String, int> _ticketGenerations = <String, int>{};
  static final Map<String, Future<void>> _ticketPersistenceTails = <String, Future<void>>{};

  @override
  Future<Result<DrawEntity>> fetchCurrent(String weekKey) async {
    try {
      final DrawEntity? draw = await _firestoreClient
          .getFromServer<DrawEntity>(
            FirebaseCollections.draws,
            weekKey,
            _fromDoc,
            sourceTag: 'draw.current',
            timeout: _readTimeout,
          )
          .timeout(_readTimeout);
      await _saveDraw(_currentKey, draw);
      return Result.success(draw ?? _defaultDraw(weekKey));
    } catch (e) {
      try {
        final Object? saved = (await _store.read(_currentKey))?['draw'];
        if (_isTransient(e) && saved is Map && saved['weekKey'] == weekKey) {
          return Result.success(_fromStoredDraw(Map<String, Object?>.from(saved)));
        }
      } on Object {
        return Result.error(ServerFailure("Couldn't load the draw: $e"));
      }
      if (_isPermissionDenied(e)) {
        try {
          await _store.delete(_currentKey);
        } on Object {}
      }
      return Result.error(ServerFailure("Couldn't load the draw: $e"));
    }
  }

  static DrawEntity _defaultDraw(String weekKey) => DrawEntity(
    weekKey: weekKey,
    status: 'open',
    closesAt: nextWeekStart(DateTime.now()),
    tickets: 0,
    participants: 0,
    prizeProMonths: 1,
    prizeItemId: _defaultItemId,
  );

  @override
  Future<Result<DrawEntity?>> fetchLastSettled() async {
    try {
      final List<DrawEntity> rows = await _firestoreClient
          .queryFromServer<DrawEntity>(
            const FirestoreQuerySpec(
              collection: FirebaseCollections.draws,
              sourceTag: 'draw.last',
              filters: <FirestoreFilter>[
                FirestoreFilter(field: 'status', op: FirestoreFilterOp.isEqualTo, value: 'settled'),
              ],
              orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'settledAt', descending: true)],
              limit: 1,
            ),
            _fromDoc,
            timeout: _readTimeout,
          )
          .timeout(_readTimeout);
      final DrawEntity? draw = rows.firstOrNull;
      await _saveDraw(_settledKey, draw);
      return Result.success(draw);
    } catch (e) {
      try {
        final Object? saved = (await _store.read(_settledKey))?['draw'];
        if (_isTransient(e) && saved is Map) {
          return Result.success(_fromStoredDraw(Map<String, Object?>.from(saved)));
        }
      } on Object {
        return Result.error(ServerFailure("Couldn't load the last winner: $e"));
      }
      if (_isPermissionDenied(e)) {
        try {
          await _store.delete(_settledKey);
        } on Object {}
      }
      return Result.error(ServerFailure("Couldn't load the last winner: $e"));
    }
  }

  @override
  Future<Result<int>> fetchMyTickets(String weekKey, String uid) async {
    final String ownerAtStart = app_state.prismUser.loggedIn ? app_state.prismUser.id : '';
    if (ownerAtStart.isEmpty || uid != ownerAtStart) {
      return Result.error(const ServerFailure("Couldn't load your tickets: account is not the active owner."));
    }
    final String key = 'tickets:$ownerAtStart';
    final int generation = _ticketGenerations[ownerAtStart] ?? 0;
    try {
      final List<int> counts = await _firestoreClient
          .queryFromServer<int>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.drawTickets,
              sourceTag: 'draw.tickets',
              filters: <FirestoreFilter>[
                FirestoreFilter(
                  field: firestoreDocumentIdField,
                  op: FirestoreFilterOp.isEqualTo,
                  value: '${weekKey}_$uid',
                ),
                FirestoreFilter(field: 'uid', op: FirestoreFilterOp.isEqualTo, value: uid),
              ],
              limit: 1,
            ),
            (data, _) => parseIntOr(data['count']),
            timeout: _readTimeout,
          )
          .timeout(_readTimeout);
      final int? count = counts.firstOrNull;
      if (!_isTicketRequestCurrent(ownerAtStart, generation)) {
        return Result.error(const ServerFailure("Couldn't load your tickets: account changed during the request."));
      }
      try {
        await _serializeTicketPersistence(ownerAtStart, () async {
          if (!_isTicketRequestCurrent(ownerAtStart, generation)) return;
          await _store.write(key, <String, Object?>{'weekKey': weekKey, 'count': count ?? 0});
        });
      } on Object {
        if (!_isTicketRequestCurrent(ownerAtStart, generation)) {
          return Result.error(const ServerFailure("Couldn't load your tickets: account changed during the request."));
        }
        return Result.success(count ?? 0);
      }
      if (!_isTicketRequestCurrent(ownerAtStart, generation)) {
        return Result.error(const ServerFailure("Couldn't load your tickets: account changed during the request."));
      }
      return Result.success(count ?? 0);
    } catch (e) {
      if (!_isTicketRequestCurrent(ownerAtStart, generation)) {
        return Result.error(const ServerFailure("Couldn't load your tickets: account changed during the request."));
      }
      Object? saved;
      try {
        saved = await _store.read(key);
      } on Object {
        return Result.error(ServerFailure("Couldn't load your tickets: $e"));
      }
      if (!_isTicketRequestCurrent(ownerAtStart, generation)) {
        return Result.error(const ServerFailure("Couldn't load your tickets: account changed during the request."));
      }
      if (_isTransient(e) && saved is Map && saved['weekKey'] == weekKey) {
        return Result.success(parseIntOr(saved['count']));
      }
      if (_isPermissionDenied(e)) {
        try {
          await _serializeTicketPersistence(ownerAtStart, () async {
            if ((_ticketGenerations[ownerAtStart] ?? 0) == generation) {
              await _store.delete(key);
            }
          });
        } on Object {}
      }
      return Result.error(ServerFailure("Couldn't load your tickets: $e"));
    }
  }

  Future<void> _saveDraw(String key, DrawEntity? draw) async {
    try {
      if (draw == null) {
        await _store.delete(key);
      } else {
        await _store.write(key, <String, Object?>{'draw': _drawToMap(draw)});
      }
    } on Object {}
  }

  static Future<void> clearForUser(String uid, {DurableJsonStore? store}) async {
    _ticketGenerations[uid] = (_ticketGenerations[uid] ?? 0) + 1;
    final int generation = _ticketGenerations[uid]!;
    await _serializeTicketPersistence(uid, () async {
      if ((_ticketGenerations[uid] ?? 0) == generation) {
        await (store ?? DurableJsonStore('draw_read_snapshots')).delete('tickets:$uid');
      }
    });
  }

  static Future<void> _serializeTicketPersistence(String uid, Future<void> Function() operation) {
    final Future<void> result = (_ticketPersistenceTails[uid] ?? Future<void>.value()).then((_) => operation());
    _ticketPersistenceTails[uid] = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static bool _isTicketRequestCurrent(String uid, int generation) =>
      app_state.prismUser.loggedIn && app_state.prismUser.id == uid && (_ticketGenerations[uid] ?? 0) == generation;

  static Map<String, Object?> _drawToMap(DrawEntity draw) => <String, Object?>{
    'weekKey': draw.weekKey,
    'status': draw.status,
    'closesAt': draw.closesAt.millisecondsSinceEpoch,
    'tickets': draw.tickets,
    'participants': draw.participants,
    'prizeProMonths': draw.prizeProMonths,
    'prizeItemId': draw.prizeItemId,
    'winnerName': draw.winnerName,
  };

  static DrawEntity _fromStoredDraw(Map<String, Object?> data) => DrawEntity(
    weekKey: data['weekKey'] as String,
    status: data['status'] as String,
    closesAt: DateTime.fromMillisecondsSinceEpoch(parseIntOr(data['closesAt']), isUtc: true),
    tickets: parseIntOr(data['tickets']),
    participants: parseIntOr(data['participants']),
    prizeProMonths: parseIntOr(data['prizeProMonths'], fallback: 1),
    prizeItemId: data['prizeItemId'] as String? ?? _defaultItemId,
    winnerName: data['winnerName'] as String?,
  );

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

  static DrawEntity _fromDoc(Map<String, dynamic> data, String docId) {
    final Map<String, dynamic> prize = toJsonMap(data['prize']);
    final String winner = data['winnerName']?.toString().trim() ?? '';
    final String itemId = prize['itemId']?.toString().trim() ?? '';
    return DrawEntity(
      weekKey: data['weekKey']?.toString() ?? docId,
      status: data['status']?.toString() ?? 'open',
      closesAt: DateTime.fromMillisecondsSinceEpoch(parseIntOr(data['closesAt']), isUtc: true),
      tickets: parseIntOr(data['tickets']),
      participants: parseIntOr(data['participants']),
      prizeProMonths: parseIntOr(prize['proMonths'], fallback: 1),
      prizeItemId: itemId.isEmpty ? _defaultItemId : itemId,
      winnerName: winner.isEmpty ? null : winner,
    );
  }
}
