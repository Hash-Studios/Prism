import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

abstract class TrendingRepository {
  /// The Prism wallpapers trending this week, most trending first. Walls that are gone, hidden or from blocked creators
  /// are left out. When the network fails, it returns the last saved list.
  Future<TrendingFetch> fetch();

  /// The last saved list, without any network read. Empty when nothing is saved or the save has expired.
  Future<List<PrismWallpaper>> readCached();
}

/// A load that failed because Firebase was not ready permits one refresh after successful initialization without
/// delaying its cache or error result.
class TrendingFetch {
  TrendingFetch.success(List<PrismWallpaper> walls, {this.retryAfterInitialization}) : result = Result.success(walls);

  TrendingFetch.error(Failure failure, {this.retryAfterInitialization}) : result = Result.error(failure);

  final Result<List<PrismWallpaper>> result;
  final Future<bool>? retryAfterInitialization;
}
