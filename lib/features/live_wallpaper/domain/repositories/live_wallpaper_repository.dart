import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_screens.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';

abstract class LiveWallpaperRepository {
  Future<LiveCapabilities> getCapabilities();

  /// [depthMapUrl] is required for [MotionStyle.depth]. [tilt] lets that style read `u_tilt`.
  /// [target] is the screen the user asked for; Android still asks again in its preview.
  Future<LiveApplyOutcome> applyMotion({
    required String imageUrl,
    required MotionStyle style,
    required LivePalette palette,
    required double screenAspectRatio,
    required bool batterySaver,
    required WallpaperTarget target,
    required LiveContentTag tag,
    String? depthMapUrl,
    bool tilt = false,
  });

  Future<LiveApplyOutcome> applyGradient({
    required GradientStyle style,
    required LivePalette palette,
    required bool batterySaver,
    required WallpaperTarget target,
    required LiveContentTag tag,
  });

  /// What each screen shows now. Read it after the system preview closes.
  Future<LiveScreens> getScreens();

  /// The screen the user chose to fill next, kept while they pick another wall. Null when none.
  WallpaperTarget? get nextTarget;
  set nextTarget(WallpaperTarget? target);

  /// Returns a typed validation failure, or null when the video can be used.
  Future<LiveApplyFailure?> validateVideo(String path);

  Future<LiveApplyOutcome> applyVideo(String path);
}
