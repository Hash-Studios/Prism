import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

abstract class PexelsWallpaperRepository {
  /// [color] is a Pexels colour name such as `blue` or `violet`.
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
    String? color,
  });

  Future<Result<PexelsWallpaper?>> fetchById(String id);
  bool hasMoreForCategory(String categoryName, {String? paginationKey});
}
