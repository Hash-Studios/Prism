import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';

abstract class FavouriteSetupsRepository {
  Future<Result<List<SetupEntity>>> fetchFavourites({required String userId});

  Future<Result<List<SetupEntity>>> toggleFavourite({required String userId, required SetupEntity setup});
}
