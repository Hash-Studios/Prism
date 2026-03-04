import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

abstract class PrismWallpaperRepository {
  Future<Result<List<PrismWallpaper>>> fetchFeed({required bool refresh});
  Future<Result<PrismWallpaper?>> fetchById(String id);
  bool get hasMore;
}
