part of 'wallpaper_history_bloc.j.dart';

@freezed
abstract class WallpaperHistoryEvent with _$WallpaperHistoryEvent {
  const factory WallpaperHistoryEvent.started() = _Started;
  const factory WallpaperHistoryEvent.cleared() = _Cleared;
}
