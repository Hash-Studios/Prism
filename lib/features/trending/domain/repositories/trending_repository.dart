import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

abstract class TrendingRepository {
  /// The Prism wallpapers trending this week, most trending first. Walls that are gone, hidden or from blocked creators
  /// are left out. When the network fails, it returns the last saved list.
  Future<Result<List<PrismWallpaper>>> fetch();

  /// The last saved list, without any network read. Empty when nothing is saved or the save has expired.
  Future<List<PrismWallpaper>> readCached();
}
