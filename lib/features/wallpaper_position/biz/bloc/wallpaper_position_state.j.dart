part of 'wallpaper_position_bloc.j.dart';

enum WallpaperPositionStatus { loading, ready, failed, applying }

@freezed
abstract class WallpaperPositionState with _$WallpaperPositionState {
  const factory WallpaperPositionState({
    required WallpaperPositionStatus status,
    required WallpaperPlacement placement,
    PlacementSource? source,

    /// Counts resets and fit changes, so the preview moves its gesture state to the placement again.
    @Default(0) int syncToken,

    /// What the last apply returned. Read it when [resultToken] changes.
    WallpaperSetResult? result,
    @Default(0) int resultToken,
  }) = _WallpaperPositionState;

  factory WallpaperPositionState.initial() =>
      const WallpaperPositionState(status: WallpaperPositionStatus.loading, placement: WallpaperPlacement());
}
