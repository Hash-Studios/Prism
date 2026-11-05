part of 'live_wallpaper_bloc.j.dart';

@freezed
abstract class LiveWallpaperEvent with _$LiveWallpaperEvent {
  const factory LiveWallpaperEvent.started({
    required bool isPro,
    @Default(<String, DateTime>{}) Map<String, DateTime> unlockedStyles,
  }) = _Started;
  const factory LiveWallpaperEvent.proChanged(bool isPro) = _ProChanged;
  const factory LiveWallpaperEvent.unlockedStylesChanged(Map<String, DateTime> unlockedStyles) = _UnlockedStylesChanged;
  const factory LiveWallpaperEvent.motionSelected(MotionStyle style) = _MotionSelected;
  const factory LiveWallpaperEvent.gradientSelected(GradientStyle style) = _GradientSelected;
  const factory LiveWallpaperEvent.batterySaverChanged(bool enabled) = _BatterySaverChanged;

  /// The screen the next shader apply is for. Shown only when the device supports a wall per screen.
  const factory LiveWallpaperEvent.targetSelected(WallpaperTarget target) = _TargetSelected;

  /// The app is back from the system preview: read what each screen shows now.
  const factory LiveWallpaperEvent.screensChecked() = _ScreensChecked;

  /// The user wants a different wall on [screen], the screen the last apply left alone.
  const factory LiveWallpaperEvent.otherScreenPicked(WallpaperTarget screen) = _OtherScreenPicked;
  const factory LiveWallpaperEvent.motionApplied({required LivePalette palette, required double screenAspectRatio}) =
      _MotionApplied;
  const factory LiveWallpaperEvent.gradientApplied({required LivePalette palette}) = _GradientApplied;
  const factory LiveWallpaperEvent.videoPicked(String path) = _VideoPicked;
  const factory LiveWallpaperEvent.videoApplied() = _VideoApplied;
  const factory LiveWallpaperEvent.outcomeHandled() = _OutcomeHandled;
}
