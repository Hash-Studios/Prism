import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

abstract class WallhavenWallpaperRepository {
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories,
    int purity,
  });

  Future<Result<WallhavenWallpaper?>> fetchById(String id);
  bool hasMoreForCategory(String categoryName);
}
