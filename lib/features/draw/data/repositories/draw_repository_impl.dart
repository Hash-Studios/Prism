import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';
import 'package:Prism/features/draw/domain/repositories/draw_repository.dart';
import 'package:Prism/features/leaderboard/domain/week_key.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DrawRepository)
class DrawRepositoryImpl implements DrawRepository {
  DrawRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;

  static const String _defaultItemId = 'frame_prism';

  @override
  Future<Result<DrawEntity>> fetchCurrent(String weekKey) async {
    try {
      final DrawEntity? draw = await _firestoreClient.getById<DrawEntity>(
        FirebaseCollections.draws,
        weekKey,
        _fromDoc,
        sourceTag: 'draw.current',
      );
      return Result.success(
        draw ??
            DrawEntity(
              weekKey: weekKey,
              status: 'open',
              closesAt: nextWeekStart(DateTime.now()),
              tickets: 0,
              participants: 0,
              prizeProMonths: 1,
              prizeItemId: _defaultItemId,
            ),
      );
    } catch (e) {
      return Result.error(ServerFailure("Couldn't load the draw: $e"));
    }
  }

  @override
  Future<Result<DrawEntity?>> fetchLastSettled() async {
    try {
      final List<DrawEntity> rows = await _firestoreClient.query<DrawEntity>(
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
      );
      return Result.success(rows.firstOrNull);
    } catch (e) {
      return Result.error(ServerFailure("Couldn't load the last winner: $e"));
    }
  }

  @override
  Future<Result<int>> fetchMyTickets(String weekKey, String uid) async {
    try {
      final int? count = await _firestoreClient.getById<int>(
        FirebaseCollections.drawTickets,
        '${weekKey}_$uid',
        (data, _) => parseIntOr(data['count']),
        sourceTag: 'draw.tickets',
      );
      return Result.success(count ?? 0);
    } catch (e) {
      return Result.error(ServerFailure("Couldn't load your tickets: $e"));
    }
  }

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
