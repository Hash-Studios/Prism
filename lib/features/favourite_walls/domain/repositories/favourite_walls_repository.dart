import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';

abstract class FavouriteWallsRepository {
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId});

  Future<Result<bool>> toggleFavourite({
    required String userId,
    required FavouriteWallEntity wall,
    required bool currentlyFavourited,
  });

  Future<Result<bool>> removeFavourite({
    required String userId,
    required String wallId,
  });

  Future<Result<bool>> clearAll({
    required String userId,
    required List<String> wallIds,
  });
}
