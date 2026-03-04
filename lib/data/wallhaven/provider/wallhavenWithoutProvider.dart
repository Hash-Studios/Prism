import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl.dart';
import 'package:Prism/logger/logger.dart';

// SHIM: delete in Phase 8
WallhavenWallpaperRepositoryImpl? _wallhavenRepo;
WallhavenWallpaperRepositoryImpl get _repo {
  _wallhavenRepo ??= WallhavenWallpaperRepositoryImpl();
  return _wallhavenRepo!;
}

List<WallhavenWallpaper> walls = [];
List<WallhavenWallpaper> wallsS = [];
int pageGetData = 1;
int pageGetQuery = 1;
List<Map<String, int>> pageNumbers = categoryDefinitions
    .where(
      (CategoryDefinition cat) =>
          cat.source == WallpaperSource.wallhaven && cat.searchType == CategorySearchType.search,
    )
    .map((CategoryDefinition cat) => <String, int>{cat.name: 1})
    .toList();

// SHIM: delete in Phase 8
Future<WallhavenWallpaper?> getWallbyID(String idU) async {
  final String id = idU.toLowerCase();
  logger.d("getWallbyID: $id");
  WallhavenWallpaper? wall;
  final result = await _repo.fetchById(id);
  result.fold(
    onSuccess: (WallhavenWallpaper? w) {
      if (w != null) {
        wall = w;
      }
      logger.d("getWallbyID done");
    },
    onFailure: (failure) {
      logger.e("getWallbyID failed: ${failure.message}");
    },
  );
  return wall;
}

// SHIM: delete in Phase 8
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
      wallsS = fetched;
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
