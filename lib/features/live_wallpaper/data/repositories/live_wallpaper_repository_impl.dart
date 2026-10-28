import 'dart:io';

import 'package:Prism/features/live_wallpaper/data/live_apply_outcome_mapper.dart';
import 'package:Prism/features/live_wallpaper/data/live_texture_preparer.dart';
import 'package:Prism/features/live_wallpaper/data/shaders/live_shader_sources.dart';
import 'package:Prism/features/live_wallpaper/data/wallpaper_capabilities_tilt.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/features/live_wallpaper/domain/repositories/live_wallpaper_repository.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:injectable/injectable.dart';

@LazySingleton(as: LiveWallpaperRepository)
class LiveWallpaperRepositoryImpl implements LiveWallpaperRepository {
  const LiveWallpaperRepositoryImpl({LiveTexturePreparer texturePreparer = const LiveTexturePreparer()})
    : _texturePreparer = texturePreparer;

  static const int defaultFrameRate = 30;
  static const int batterySaverFrameRate = 15;
  static const int maxVideoBytes = 256 * 1024 * 1024;

  final LiveTexturePreparer _texturePreparer;

  @override
  Future<LiveCapabilities> getCapabilities() async {
    final aw.WallpaperCapabilities capabilities = await aw.AsyncWallpaper.getCapabilities();
    return LiveCapabilities(
      supportsShaders: capabilities.supportsOpenGlLiveWallpaper,
      supportsVideo: capabilities.supportsLiveWallpaper,
      supportsTilt: capabilities.supportsTilt,
    );
  }

  @override
  Future<LiveApplyOutcome> applyMotion({
    required String imageUrl,
    required MotionStyle style,
    required LivePalette palette,
    required double screenAspectRatio,
    required bool batterySaver,
    String? depthMapUrl,
    bool tilt = false,
  }) async {
    if (style.needsDepthMap && depthMapUrl == null) {
      return const LiveApplyOutcome.failed(LiveApplyFailure.styleUnavailable);
    }
    final List<String> texturePaths;
    try {
      if (style.needsDepthMap) {
        final ({String photo, String depth}) textures = await _texturePreparer.prepareWithDepth(
          imageUrl,
          depthMapUrl!,
          screenAspectRatio,
        );
        texturePaths = <String>[textures.photo, textures.depth];
      } else {
        texturePaths = <String>[await _texturePreparer.prepare(imageUrl, screenAspectRatio)];
      }
    } on LiveTextureException catch (error) {
      return LiveApplyOutcome.failed(error.failure);
    }
    return _applyShader(LiveShaderSources.motion(style, palette, tilt: tilt), <aw.WallpaperSource>[
      for (final String path in texturePaths) aw.WallpaperSource.filePath(path),
    ], batterySaver);
  }

  @override
  Future<LiveApplyOutcome> applyGradient({
    required GradientStyle style,
    required LivePalette palette,
    required bool batterySaver,
  }) {
    return _applyShader(LiveShaderSources.gradient(style, palette), const <aw.WallpaperSource>[], batterySaver);
  }

  Future<LiveApplyOutcome> _applyShader(String shader, List<aw.WallpaperSource> textures, bool batterySaver) async {
    final aw.OpenGlLiveWallpaperRequest request = aw.OpenGlLiveWallpaperRequest(
      fragmentShader: shader,
      textures: textures,
      frameRate: batterySaver ? batterySaverFrameRate : defaultFrameRate,
    );
    try {
      return liveApplyOutcomeFromResult(await aw.AsyncWallpaper.setOpenGlLiveWallpaper(request));
    } catch (_) {
      return const LiveApplyOutcome.failed(LiveApplyFailure.setFailed);
    }
  }

  @override
  Future<LiveApplyFailure?> validateVideo(String path) async {
    try {
      final File file = File(path);
      if (!await file.exists()) return LiveApplyFailure.videoReadFailed;
      if (await file.length() > maxVideoBytes) {
        return LiveApplyFailure.videoTooLarge;
      }
      return null;
    } catch (_) {
      return LiveApplyFailure.videoReadFailed;
    }
  }

  @override
  Future<LiveApplyOutcome> applyVideo(String path) async {
    final LiveApplyFailure? problem = await validateVideo(path);
    if (problem != null) return LiveApplyOutcome.failed(problem);
    final aw.VideoWallpaperRequest request = aw.VideoWallpaperRequest(source: aw.WallpaperSource.filePath(path));
    try {
      final aw.WallpaperOperationResult prepared = await aw.AsyncWallpaper.setVideoWallpaper(request);
      if (prepared.status != aw.WallpaperOperationStatus.awaitingUserConfirmation) {
        return liveApplyOutcomeFromResult(prepared);
      }
      return liveApplyOutcomeFromResult(await aw.AsyncWallpaper.openLiveWallpaperPreview(request));
    } catch (_) {
      return const LiveApplyOutcome.failed(LiveApplyFailure.setFailed);
    }
  }
}
