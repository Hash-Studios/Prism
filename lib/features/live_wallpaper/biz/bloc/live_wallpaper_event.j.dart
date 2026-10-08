part of 'live_wallpaper_bloc.j.dart';

@freezed
abstract class LiveWallpaperEvent with _$LiveWallpaperEvent {
  const factory LiveWallpaperEvent.started({required bool isPro}) = _Started;
  const factory LiveWallpaperEvent.proChanged(bool isPro) = _ProChanged;
  const factory LiveWallpaperEvent.motionSelected(MotionStyle style) = _MotionSelected;
  const factory LiveWallpaperEvent.gradientSelected(GradientStyle style) = _GradientSelected;
  const factory LiveWallpaperEvent.batterySaverChanged(bool enabled) = _BatterySaverChanged;
  const factory LiveWallpaperEvent.motionApplied({required LivePalette palette, required double screenAspectRatio}) =
      _MotionApplied;
  const factory LiveWallpaperEvent.gradientApplied({required LivePalette palette}) = _GradientApplied;
  const factory LiveWallpaperEvent.videoPicked(String path) = _VideoPicked;
  const factory LiveWallpaperEvent.videoApplied() = _VideoApplied;
  const factory LiveWallpaperEvent.outcomeHandled() = _OutcomeHandled;
}
