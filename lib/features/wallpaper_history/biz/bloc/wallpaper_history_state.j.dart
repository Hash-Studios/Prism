part of 'wallpaper_history_bloc.j.dart';

@freezed
abstract class WallpaperHistoryState with _$WallpaperHistoryState {
  const factory WallpaperHistoryState({required List<AppliedWallpaper> items}) = _WallpaperHistoryState;

  factory WallpaperHistoryState.initial() => const WallpaperHistoryState(items: <AppliedWallpaper>[]);
}
