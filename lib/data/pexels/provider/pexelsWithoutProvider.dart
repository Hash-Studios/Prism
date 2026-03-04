import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
import 'package:Prism/logger/logger.dart';

// SHIM: delete in Phase 8
PexelsWallpaperRepositoryImpl? _pexelsRepo;
PexelsWallpaperRepositoryImpl get _repo {
  _pexelsRepo ??= PexelsWallpaperRepositoryImpl();
  return _pexelsRepo!;
}

List<PexelsWallpaper> wallsP = [];
List<PexelsWallpaper> wallsPS = [];
List<PexelsWallpaper> wallsC = [];
PexelsWallpaper? wall;
int pageGetDataP = 1;
int pageGetQueryP = 1;
List<Map<String, int>> pageNumbersP = categoryDefinitions
    .where(
      (CategoryDefinition cat) => cat.source == WallpaperSource.pexels && cat.searchType == CategorySearchType.search,
    )
    .map((CategoryDefinition cat) => <String, int>{cat.name: 1})
    .toList();

// SHIM: delete in Phase 8
Future<List<PexelsWallpaper>> categoryDataFetcherP(String categoryName, String mode) async {
  final bool refresh = mode == "r";
  if (refresh) {
    wallsP = [];
  }
  final result = await _repo.fetchFeed(categoryName: categoryName, refresh: refresh);
  result.fold(
    onSuccess: (List<PexelsWallpaper> fetched) {
      if (refresh) {
        wallsP = fetched;
      } else {
        wallsP.addAll(fetched);
      }
      logger.d("categoryDataFetcherP done: ${fetched.length}");
    },
    onFailure: (failure) {
      logger.e("categoryDataFetcherP failed: ${failure.message}");
    },
  );
  return wallsP;
}

int pageColorsP = 1;

// SHIM: delete in Phase 8
Future<List<PexelsWallpaper>> getDataP(String mode) async {
  final bool refresh = mode == "r";
  if (refresh) {
    wallsP = [];
    pageGetDataP = 1;
  } else {
    pageGetDataP = pageGetDataP + 1;
  }
  final result = await _repo.fetchFeed(categoryName: 'Curated', refresh: refresh);
  result.fold(
    onSuccess: (List<PexelsWallpaper> fetched) {
      if (refresh) {
        wallsP = fetched;
      } else {
        wallsP.addAll(fetched);
      }
      logger.d("getDataP done: ${fetched.length}");
    },
    onFailure: (failure) {
      logger.e("getDataP failed: ${failure.message}");
    },
  );
  return wallsP;
}

// SHIM: delete in Phase 8
Future<PexelsWallpaper?> getWallbyIDP(String? id) async {
  logger.d("getWallbyIDP: $id");
  wall = null;
  if (id == null) return null;
  final result = await _repo.fetchById(id);
  result.fold(
    onSuccess: (PexelsWallpaper? w) {
      if (w != null) {
        wall = w;
      }
      logger.d("getWallbyIDP done");
    },
    onFailure: (failure) {
      logger.e("getWallbyIDP failed: ${failure.message}");
    },
  );
  return wall;
}

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
      wallsC = fetched;
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
