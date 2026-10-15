import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';

abstract class LiveWallpaperRepository {
  Future<LiveCapabilities> getCapabilities();

  Future<LiveApplyOutcome> applyMotion({
    required String imageUrl,
    required MotionStyle style,
    required LivePalette palette,
    required double screenAspectRatio,
    required bool batterySaver,
  });

  Future<LiveApplyOutcome> applyGradient({
    required GradientStyle style,
    required LivePalette palette,
    required bool batterySaver,
  });

  /// Returns a user-facing problem with the video, or null when it can be used.
  Future<String?> validateVideo(String path);

  Future<LiveApplyOutcome> applyVideo(String path);
}
