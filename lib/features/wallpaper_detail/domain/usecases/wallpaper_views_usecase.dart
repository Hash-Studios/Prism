import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:injectable/injectable.dart';

/// Records a Prism wallpaper detail view and returns the updated count (Firestore via callable).
@lazySingleton
class RecordPrismWallpaperViewsUsecase {
  RecordPrismWallpaperViewsUsecase(this._viewStatsRepository);

  final ViewStatsRepository _viewStatsRepository;

  Future<Result<String>> call(String wallId) {
    return _viewStatsRepository.recordWallpaperView(wallId.toUpperCase());
  }
}
