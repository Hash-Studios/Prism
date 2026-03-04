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
