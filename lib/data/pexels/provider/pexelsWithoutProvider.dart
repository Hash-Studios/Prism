import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';

// SHIM: delete in Phase 8
PexelsWallpaperRepository get _repo => getIt<PexelsWallpaperRepository>();

List<PexelsWallpaper> wallsPS = [];
List<PexelsWallpaper> wallsC = [];
PexelsWallpaper? wall;
int pageGetQueryP = 1;

int pageColorsP = 1;

// SHIM: delete in Phase 8
Future<List<PexelsWallpaper>> getWallsPbyQuery(String query) async {
  wallsPS = [];
  final result = await _repo.fetchFeed(categoryName: query, refresh: true);
  result.fold(
    onSuccess: (List<PexelsWallpaper> fetched) {
      wallsPS = fetched;
      pageGetQueryP = 2;
      logger.d("getWallsPbyQuery done: ${wallsPS.length}");
    },
    onFailure: (failure) {
      logger.e("getWallsPbyQuery failed: ${failure.message}");
    },
  );
  return wallsPS;
}

Future<List<PexelsWallpaper>> getWallsPbyQueryPage(String query) async {
  final result = await _repo.fetchFeed(categoryName: query, refresh: false);
  result.fold(
    onSuccess: (List<PexelsWallpaper> fetched) {
      wallsPS.addAll(fetched);
      pageGetQueryP = pageGetQueryP + 1;
      logger.d("getWallsPbyQueryPage done: ${fetched.length}");
    },
    onFailure: (failure) {
      logger.e("getWallsPbyQueryPage failed: ${failure.message}");
    },
  );
  return wallsPS;
}

Future<List<PexelsWallpaper>> getWallsPbyColor(String query) async {
  logger.d("getWallsPbyColor: $query");
  wallsC = [];
  pageColorsP = 1;
  final result = await _repo.fetchFeed(categoryName: query, refresh: true);
  result.fold(
    onSuccess: (List<PexelsWallpaper> fetched) {
      wallsC = List.of(fetched);
      pageColorsP = 2;
      logger.d("getWallsPbyColor done: ${wallsC.length}");
    },
    onFailure: (failure) {
      logger.e("getWallsPbyColor failed: ${failure.message}");
    },
  );
  return wallsC;
}

Future<List<PexelsWallpaper>> getWallsPbyColorPage(String query) async {
  logger.d("getWallsPbyColorPage: $query page $pageColorsP");
  final result = await _repo.fetchFeed(categoryName: query, refresh: false);
  result.fold(
    onSuccess: (List<PexelsWallpaper> fetched) {
      wallsC.addAll(fetched);
      pageColorsP = pageColorsP + 1;
      logger.d("getWallsPbyColorPage done: ${fetched.length}");
    },
    onFailure: (failure) {
      logger.e("getWallsPbyColorPage failed: ${failure.message}");
    },
  );
  return wallsC;
}
