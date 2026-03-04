import 'dart:async';

import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/repositories/prism_wallpaper_repository_impl.dart';
import 'package:Prism/logger/logger.dart';

// SHIM: delete in Phase 8 — lazy singleton wiring old globals to typed repository.
PrismWallpaperRepositoryImpl? _prismRepo;
PrismWallpaperRepositoryImpl get _repo {
  _prismRepo ??= PrismWallpaperRepositoryImpl(firestoreClient);
  return _prismRepo!;
}

List<PrismWallpaper>? prismWalls;
List<PrismWallpaper>? subPrismWalls;
bool prismHasMore = true;

// SHIM: delete in Phase 8
Future<List<PrismWallpaper>?> getPrismWalls() async {
  logger.d("[PrismFeed] getPrismWalls start");
  prismWalls = [];
  subPrismWalls = [];
  prismHasMore = true;
  try {
    final result = await _repo.fetchFeed(refresh: true);
    result.fold(
      onSuccess: (List<PrismWallpaper> walls) {
        prismHasMore = _repo.hasMore;
        prismWalls = walls;
        subPrismWalls = List<PrismWallpaper>.from(walls);
        logger.i("[PrismFeed] getPrismWalls success", fields: <String, Object?>{"count": walls.length});
      },
      onFailure: (failure) {
        subPrismWalls = <PrismWallpaper>[];
        logger.e("[PrismFeed] getPrismWalls failed", fields: <String, Object?>{"failure": failure.message});
      },
    );
  } catch (error, stackTrace) {
    subPrismWalls = <PrismWallpaper>[];
    logger.e("[PrismFeed] getPrismWalls failed", error: error, stackTrace: stackTrace);
    rethrow;
  }
  return subPrismWalls;
}

// SHIM: delete in Phase 8
Future<List<PrismWallpaper>?> seeMorePrism() async {
  logger.d("[PrismFeed] seeMorePrism start", fields: <String, Object?>{"existing": subPrismWalls?.length ?? 0});
  if (!_repo.hasMore) {
    logger.w("[PrismFeed] seeMorePrism skipped: no more pages");
    prismHasMore = false;
    return subPrismWalls ?? prismWalls ?? [];
  }
  prismWalls ??= <PrismWallpaper>[];
  subPrismWalls ??= <PrismWallpaper>[];
  try {
    final result = await _repo.fetchFeed(refresh: false);
    result.fold(
      onSuccess: (List<PrismWallpaper> walls) {
        prismHasMore = _repo.hasMore;
        prismWalls?.addAll(walls);
        subPrismWalls?.addAll(walls);
        logger.i(
          "[PrismFeed] seeMorePrism success",
          fields: <String, Object?>{"fetched": walls.length, "total": subPrismWalls?.length},
        );
      },
      onFailure: (failure) {
        prismHasMore = false;
        logger.e("[PrismFeed] seeMorePrism failed", fields: <String, Object?>{"failure": failure.message});
      },
    );
  } catch (error, stackTrace) {
    prismHasMore = false;
    logger.e("[PrismFeed] seeMorePrism failed", error: error, stackTrace: stackTrace);
    rethrow;
  }
  return subPrismWalls;
}

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
