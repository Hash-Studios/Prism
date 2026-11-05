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

    /// The screen the next shader apply is for. Android asks again in its preview.
    required WallpaperTarget target,

    /// Paid style id to the end of its coin unlock, as the server stored it.
    @Default(<String, DateTime>{}) Map<String, DateTime> unlockedStyles,
    String? videoPath,
    LiveApplyOutcome? outcome,

    /// The apply that waits for the user to finish in the system preview.
    LiveContentTag? pendingTag,
  }) = _LiveWallpaperState;

  factory LiveWallpaperState.initial() => const LiveWallpaperState(
    status: LiveWallpaperStatus.loading,
    capabilities: LiveCapabilities.none,
    isPro: false,
    motionStyle: MotionStyle.drift,
    gradientStyle: GradientStyle.aurora,
    batterySaver: false,
    applying: false,
    target: WallpaperTarget.home,
  );
}

extension LiveWallpaperStateLocks on LiveWallpaperState {
  bool isLocked(String styleId, {required bool isFree, DateTime? now}) =>
      isLiveStyleLocked(styleId, isFree: isFree, isPro: isPro, unlockedStyles: unlockedStyles, now: now);
}
