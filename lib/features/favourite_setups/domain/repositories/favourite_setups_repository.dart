import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';

abstract class FavouriteSetupsRepository {
  Future<Result<List<FavouriteSetupEntity>>> fetchFavourites({required String userId});

  Future<Result<List<FavouriteSetupEntity>>> toggleFavourite({
    required String userId,
    required FavouriteSetupEntity setup,
  });

  Future<Result<List<FavouriteSetupEntity>>> removeFavourite({required String userId, required String setupId});

  Future<Result<List<FavouriteSetupEntity>>> clearAll({required String userId});
}
