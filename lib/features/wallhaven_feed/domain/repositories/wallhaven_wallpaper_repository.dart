import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

abstract class WallhavenWallpaperRepository {
  /// [portraitOnly] adds `ratios=portrait`. [minResolution] (for example `1080x1920`) maps to `atleast`.
  /// [sorting] is a raw Wallhaven value such as `date_added` or `toplist`; `null` keeps the API default.
  /// Only a [refresh] reads or writes the cached first page. A failed later page is an error.
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories,
    int purity,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
    String? minResolution,
    String? sorting,
  });

  Future<Result<List<WallhavenWallpaper>>> fetchToplist({int page = 1});

  Future<Result<WallhavenWallpaper?>> fetchById(String id);
  bool hasMoreForCategory(String categoryName, {String? paginationKey});
}
