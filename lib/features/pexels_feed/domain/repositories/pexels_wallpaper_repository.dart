import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

abstract class PexelsWallpaperRepository {
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
  });

  /// Wallpapers matching a colour. [hex] is six hex digits, with or without a leading `#`.
  Future<Result<List<PexelsWallpaper>>> fetchColorFeed({required String hex, required bool refresh});

  Future<Result<PexelsWallpaper?>> fetchById(String id);
  bool hasMoreForCategory(String categoryName, {String? paginationKey});
}
