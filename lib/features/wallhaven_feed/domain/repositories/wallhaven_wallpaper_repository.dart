import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

abstract class WallhavenWallpaperRepository {
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories,
    int purity,
    int startPage = 1,
    String? paginationKey,
  });

  Future<Result<List<WallhavenWallpaper>>> fetchToplist({int page = 1});

  Future<Result<WallhavenWallpaper?>> fetchById(String id);
  bool hasMoreForCategory(String categoryName, {String? paginationKey});
}
