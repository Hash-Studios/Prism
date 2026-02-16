import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';

abstract class FavouriteWallsRepository {
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites(
      {required String userId});

  Future<Result<List<FavouriteWallEntity>>> toggleFavourite({
    required String userId,
    required FavouriteWallEntity wall,
  });

  Future<Result<List<FavouriteWallEntity>>> removeFavourite({
    required String userId,
    required String wallId,
  });

  Future<Result<List<FavouriteWallEntity>>> clearAll({required String userId});
}
