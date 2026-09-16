import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';

// Legacy data helpers still used by the Wallhaven feed screens; wraps the repository.
WallhavenWallpaperRepository get _repo => getIt<WallhavenWallpaperRepository>();

List<WallhavenWallpaper> walls = [];
List<WallhavenWallpaper> wallsS = [];
int pageGetQuery = 1;

Future<List<WallhavenWallpaper>> getWallsbyQuery(String query, int? categories, int? purity) async {
  logger.d("getWallsbyQuery: $query");
  wallsS = [];
  final result = await _repo.fetchFeed(
    categoryName: query,
    refresh: true,
    categories: categories ?? 100,
    purity: purity ?? 100,
  );
  result.fold(
    onSuccess: (List<WallhavenWallpaper> fetched) {
      wallsS = List<WallhavenWallpaper>.of(fetched);
      pageGetQuery = 2;
      logger.d("getWallsbyQuery done: ${wallsS.length}");
    },
    onFailure: (failure) {
      logger.e("getWallsbyQuery failed: ${failure.message}");
    },
  );
  return wallsS;
}

Future<List<WallhavenWallpaper>> getWallsbyQueryPage(String query, int? categories, int? purity) async {
  logger.d("getWallsbyQueryPage: $query page $pageGetQuery");
  final result = await _repo.fetchFeed(
    categoryName: query,
    refresh: false,
    categories: categories ?? 100,
    purity: purity ?? 100,
  );
  result.fold(
    onSuccess: (List<WallhavenWallpaper> fetched) {
      wallsS.addAll(fetched);
      pageGetQuery = pageGetQuery + 1;
      logger.d("getWallsbyQueryPage done: ${fetched.length}");
    },
    onFailure: (failure) {
      logger.e("getWallsbyQueryPage failed: ${failure.message}");
    },
  );
  return wallsS;
}
