import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: WallOfTheDayRepository)
class WallOfTheDayRepositoryImpl implements WallOfTheDayRepository {
  WallOfTheDayRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;

  @override
  Future<Result<WallOfTheDayEntity?>> fetchToday() async {
    try {
      final entity = await _firestoreClient.getById<WallOfTheDayEntity>(
        FirebaseCollections.wallOfTheDay,
        'current',
        (data, _) => WallOfTheDayEntity.fromMap(data),
        sourceTag: 'wotd.fetchToday',
      );
      return Result.success(entity);
    } catch (e) {
      return Result.error(ServerFailure('Failed to fetch Wall of the Day: $e'));
    }
  }
}
