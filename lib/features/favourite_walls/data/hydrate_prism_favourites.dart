import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';

Future<List<FavouriteWallEntity>> hydratePrismFavourites(
  List<FavouriteWallEntity> walls,
  PrismWallpaperRepository prismWallpapers,
) async {
  final hydrated = walls.toList();
  final expired = Completer<Result<PrismWallpaper?>?>();
  final timer = Timer(const Duration(seconds: 8), () => expired.complete(null));
  var nextIndex = 0;

  Future<void> hydrateNext() async {
    while (nextIndex < walls.length && !expired.isCompleted) {
      final index = nextIndex++;
      final wall = walls[index];
      if (wall is! PrismFavouriteWall || BundledWallpapers.isStarterIdentity(wall.id, wall.source)) continue;
      try {
        final result = await Future.any<Result<PrismWallpaper?>?>([
          prismWallpapers.fetchCanonicalById(wall.id),
          expired.future,
        ]);
        final canonical = result?.data;
        if (result != null && result.isSuccess && canonical != null && canonical.id == wall.id) {
          hydrated[index] = PrismFavouriteWall(
            id: wall.id,
            wallpaper: canonical,
            favouritedAt: wall.favouritedAt,
            syncStatus: wall.syncStatus,
          );
        }
      } catch (_) {
        continue;
      }
    }
  }

  try {
    await Future.wait(List.generate(math.min(4, walls.length), (_) => hydrateNext()));
    return hydrated;
  } finally {
    timer.cancel();
  }
}
