import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/drops/data/drop_mapper.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/domain/repositories/drops_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DropsRepository)
class DropsRepositoryImpl implements DropsRepository {
  DropsRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;

  @override
  Future<Result<DropEntity?>> fetchLive(DateTime now) async {
    try {
      final List<DropEntity?> rows = await _firestoreClient.query<DropEntity?>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.drops,
          sourceTag: 'drops.live',
          filters: <FirestoreFilter>[
            FirestoreFilter(field: 'endsAt', op: FirestoreFilterOp.isGreaterThan, value: now.millisecondsSinceEpoch),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'endsAt')],
          limit: 1,
        ),
        (data, docId) => dropFromMap(data, docId),
      );
      final DropEntity? drop = rows.nonNulls.firstOrNull;
      return Result.success(drop != null && drop.isLiveAt(now) ? drop : null);
    } catch (error, stackTrace) {
      logger.e('[DropsRepository] fetchLive failed', error: error, stackTrace: stackTrace);
      return Result.error(const ServerFailure("Couldn't load this week's Drop. Check your connection and try again."));
    }
  }

  @override
  Future<Result<DropEntity?>> fetchByWeekKey(String weekKey) async {
    try {
      final DropEntity? drop = await _firestoreClient.getById<DropEntity?>(
        FirebaseCollections.drops,
        weekKey,
        (data, docId) => dropFromMap(data, docId),
        sourceTag: 'drops.byWeek',
      );
      return Result.success(drop);
    } catch (error, stackTrace) {
      logger.e('[DropsRepository] fetchByWeekKey failed', error: error, stackTrace: stackTrace);
      return Result.error(const ServerFailure("Couldn't load this Drop. Check your connection and try again."));
    }
  }
}
