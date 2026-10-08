part of 'wallpaper_history_bloc.j.dart';

@freezed
abstract class WallpaperHistoryEvent with _$WallpaperHistoryEvent {
  const factory WallpaperHistoryEvent.started() = _Started;
  const factory WallpaperHistoryEvent.cleared() = _Cleared;
  const factory WallpaperHistoryEvent.removed(String id) = _Removed;
  const factory WallpaperHistoryEvent.restored(AppliedWallpaper item) = _Restored;
}
