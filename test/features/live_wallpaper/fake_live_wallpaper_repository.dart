import 'dart:async';

import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_screens.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/features/live_wallpaper/domain/repositories/live_wallpaper_repository.dart';

class FakeLiveWallpaperRepository implements LiveWallpaperRepository {
  LiveCapabilities capabilities = const LiveCapabilities(supportsShaders: true, supportsVideo: true);
  Object? capabilitiesError;
  LiveApplyOutcome outcome = const LiveApplyOutcome.confirmInPreview();
  LiveApplyFailure? videoProblem;
  Completer<LiveApplyOutcome>? applyResult;
  Completer<LiveScreens>? screensResult;

  /// What each screen shows, returned by [getScreens].
  LiveScreens screens = LiveScreens.unknown;

  @override
  WallpaperTarget? nextTarget;

  /// The target and tag of the last [applyMotion] or [applyGradient] call.
  WallpaperTarget? lastTarget;
  LiveContentTag? lastTag;

  int getScreensCalls = 0;

  final List<MotionStyle> motionApplies = <MotionStyle>[];
  final List<GradientStyle> gradientApplies = <GradientStyle>[];
  final List<LivePalette> gradientPalettes = <LivePalette>[];
  final List<bool> batterySaverValues = <bool>[];
  final List<String> videoApplies = <String>[];
  final List<String> motionUrls = <String>[];
  final List<String?> depthMapUrls = <String?>[];
  final List<bool> tiltValues = <bool>[];

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
    required WallpaperTarget target,
    required LiveContentTag tag,
    String? depthMapUrl,
    bool tilt = false,
  }) async {
    motionUrls.add(imageUrl);
    motionApplies.add(style);
    batterySaverValues.add(batterySaver);
    depthMapUrls.add(depthMapUrl);
    tiltValues.add(tilt);
    lastTarget = target;
    lastTag = tag;
    return applyResult?.future ?? outcome;
  }

  @override
  Future<LiveApplyOutcome> applyGradient({
    required GradientStyle style,
    required LivePalette palette,
    required bool batterySaver,
    required WallpaperTarget target,
    required LiveContentTag tag,
  }) async {
    gradientApplies.add(style);
    gradientPalettes.add(palette);
    batterySaverValues.add(batterySaver);
    lastTarget = target;
    lastTag = tag;
    return applyResult?.future ?? outcome;
  }

  @override
  Future<LiveScreens> getScreens() async {
    getScreensCalls++;
    return screensResult?.future ?? screens;
  }

  @override
  Future<LiveApplyFailure?> validateVideo(String path) async => videoProblem;

  @override
  Future<LiveApplyOutcome> applyVideo(String path) async {
    videoApplies.add(path);
    return outcome;
  }
}
