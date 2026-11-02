import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';

abstract class LiveWallpaperRepository {
  Future<LiveCapabilities> getCapabilities();

  /// [depthMapUrl] is required for [MotionStyle.depth]. [tilt] lets that style read `u_tilt`.
  Future<LiveApplyOutcome> applyMotion({
    required String imageUrl,
    required MotionStyle style,
    required LivePalette palette,
    required double screenAspectRatio,
    required bool batterySaver,
    String? depthMapUrl,
    bool tilt = false,
  });

  Future<LiveApplyOutcome> applyGradient({
    required GradientStyle style,
    required LivePalette palette,
    required bool batterySaver,
  });

  /// Returns a typed validation failure, or null when the video can be used.
  Future<LiveApplyFailure?> validateVideo(String path);

  Future<LiveApplyOutcome> applyVideo(String path);
}
