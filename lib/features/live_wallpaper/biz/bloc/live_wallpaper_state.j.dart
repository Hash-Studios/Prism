part of 'live_wallpaper_bloc.j.dart';

enum LiveWallpaperStatus { loading, ready, unsupported }

@freezed
abstract class LiveWallpaperState with _$LiveWallpaperState {
  const factory LiveWallpaperState({
    required LiveWallpaperStatus status,
    required LiveCapabilities capabilities,
    required bool isPro,
    required MotionStyle motionStyle,
    required GradientStyle gradientStyle,
    required bool batterySaver,
    required bool applying,

    /// Paid style id to the end of its coin unlock, as the server stored it.
    @Default(<String, DateTime>{}) Map<String, DateTime> unlockedStyles,
    String? videoPath,
    LiveApplyOutcome? outcome,
  }) = _LiveWallpaperState;

  factory LiveWallpaperState.initial() => const LiveWallpaperState(
    status: LiveWallpaperStatus.loading,
    capabilities: LiveCapabilities.none,
    isPro: false,
    motionStyle: MotionStyle.drift,
    gradientStyle: GradientStyle.aurora,
    batterySaver: false,
    applying: false,
  );
}

extension LiveWallpaperStateLocks on LiveWallpaperState {
  bool isLocked(String styleId, {required bool isFree, DateTime? now}) =>
      isLiveStyleLocked(styleId, isFree: isFree, isPro: isPro, unlockedStyles: unlockedStyles, now: now);
}
