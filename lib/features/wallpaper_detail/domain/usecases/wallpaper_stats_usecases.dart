import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:injectable/injectable.dart';

/// Counts one download, set or share on a Prism wallpaper. The count feeds "Set N times" and creator stats.
///
/// Call it for Prism walls only, after the action worked. The result is safe to ignore: an older backend, a guest, or
/// no network never throws.
@lazySingleton
class RecordWallpaperActionUseCase {
  RecordWallpaperActionUseCase(this._viewStatsRepository);

  final ViewStatsRepository _viewStatsRepository;

  Future<Result<void>> call(String wallId, WallpaperAction action) {
    return _viewStatsRepository.recordWallpaperAction(wallId, action);
  }
}

/// How many times a Prism wallpaper was set. Null when no one set it yet.
@lazySingleton
class GetWallpaperSetCountUseCase {
  GetWallpaperSetCountUseCase(this._viewStatsRepository);

  final ViewStatsRepository _viewStatsRepository;

  Future<Result<int?>> call(String wallId) => _viewStatsRepository.fetchWallpaperSetCount(wallId);
}
