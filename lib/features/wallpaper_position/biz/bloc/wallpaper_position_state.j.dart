part of 'wallpaper_position_bloc.j.dart';

enum WallpaperPositionStatus { loading, ready, failed, rendering }

@freezed
abstract class WallpaperPositionState with _$WallpaperPositionState {
  const factory WallpaperPositionState({
    required WallpaperPositionStatus status,
    required WallpaperPlacement placement,
    PlacementSource? source,

    /// Counts resets and fit changes, so the preview moves its gesture state to the placement again.
    @Default(0) int syncToken,

    /// The render from the last Done. Read it when [placedToken] changes.
    PlacedWallpaper? placed,
    @Default(0) int placedToken,

    /// Counts renders that failed.
    @Default(0) int renderErrorToken,
  }) = _WallpaperPositionState;

  factory WallpaperPositionState.initial() =>
      const WallpaperPositionState(status: WallpaperPositionStatus.loading, placement: WallpaperPlacement());
}
