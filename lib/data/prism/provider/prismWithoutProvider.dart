import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';

// SHIM: delete in Phase 8 — lazy singleton wiring old globals to typed repository.
PrismWallpaperRepository get _repo => getIt<PrismWallpaperRepository>();

List<PrismWallpaper>? prismWalls;
List<PrismWallpaper>? subPrismWalls;
bool prismHasMore = true;

Future<PrismWallpaper?> getDataByID(String? id) async {
  PrismWallpaper? wallP;
  final result = await _repo.fetchById(id ?? '');
  result.fold(
    onSuccess: (PrismWallpaper? wall) {
      wallP = wall;
    },
    onFailure: (failure) {
      logger.e("[PrismFeed] getDataByID failed", fields: <String, Object?>{"failure": failure.message});
    },
  );

  return wallP;
}
