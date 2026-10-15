import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/features/live_wallpaper/domain/repositories/live_wallpaper_repository.dart';

class FakeLiveWallpaperRepository implements LiveWallpaperRepository {
  LiveCapabilities capabilities = const LiveCapabilities(supportsShaders: true, supportsVideo: true);
  Object? capabilitiesError;
  LiveApplyOutcome outcome = const LiveApplyOutcome.confirmInPreview();
  String? videoProblem;

  final List<MotionStyle> motionApplies = <MotionStyle>[];
  final List<GradientStyle> gradientApplies = <GradientStyle>[];
  final List<LivePalette> gradientPalettes = <LivePalette>[];
  final List<bool> batterySaverValues = <bool>[];
  final List<String> videoApplies = <String>[];
  final List<String> motionUrls = <String>[];

  @override
  Future<LiveCapabilities> getCapabilities() async {
    if (capabilitiesError case final Object error) throw error;
    return capabilities;
  }

  @override
  Future<LiveApplyOutcome> applyMotion({
    required String imageUrl,
    required MotionStyle style,
    required LivePalette palette,
    required double screenAspectRatio,
    required bool batterySaver,
  }) async {
    motionUrls.add(imageUrl);
    motionApplies.add(style);
    batterySaverValues.add(batterySaver);
    return outcome;
  }

  @override
  Future<LiveApplyOutcome> applyGradient({
    required GradientStyle style,
    required LivePalette palette,
    required bool batterySaver,
  }) async {
    gradientApplies.add(style);
    gradientPalettes.add(palette);
    batterySaverValues.add(batterySaver);
    return outcome;
  }

  @override
  Future<String?> validateVideo(String path) async => videoProblem;

  @override
  Future<LiveApplyOutcome> applyVideo(String path) async {
    videoApplies.add(path);
    return outcome;
  }
}
