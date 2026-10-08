import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

abstract class PrismWallpaperRepository {
  Future<Result<List<PrismWallpaper>>> fetchFeed({required bool refresh});

  /// Reviewed walls whose classifier category is [category], newest first. Hides blocked creators.
  Future<Result<List<PrismWallpaper>>> fetchByCategory(
    String category, {
    String? startAfterDocId,
    int limit = 24,
    String sourceTag = 'category_feed.prism_first',
  });
  Future<Result<PrismWallpaper?>> fetchById(String id);

  /// Loads [walls/{documentId}] by Firestore document id (WOTD pointer uses doc ids).
  Future<Result<PrismWallpaper?>> fetchByDocumentId(String documentId);
  Future<Result<List<PrismWallpaper>>> fetchStreakShopWallpapers();
  bool get hasMore;
}
