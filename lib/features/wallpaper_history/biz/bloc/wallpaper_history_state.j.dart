part of 'wallpaper_history_bloc.j.dart';

@freezed
abstract class WallpaperHistoryState with _$WallpaperHistoryState {
  /// [items] are the walls set or downloaded, newest first. [viewed] are the recently viewed walls, and
  /// [viewingHistoryOn] is the Save viewing history setting.
  const factory WallpaperHistoryState({
    required List<AppliedWallpaper> items,
    @Default(<HistoryWall>[]) List<HistoryWall> viewed,
    @Default(true) bool viewingHistoryOn,
  }) = _WallpaperHistoryState;

  factory WallpaperHistoryState.initial() => const WallpaperHistoryState(items: <AppliedWallpaper>[]);
}
