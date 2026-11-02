import 'dart:io';
import 'dart:ui' show Color;

import 'package:Prism/core/platform/pigeon/prism_live_photo_api.g.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_photo/domain/repositories/live_photo_repository.dart';
import 'package:Prism/features/live_wallpaper/data/live_texture_preparer.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: LivePhotoRepository)
class LivePhotoRepositoryImpl implements LivePhotoRepository, PrismLivePhotoFlutterApi {
  LivePhotoRepositoryImpl({
    LiveTexturePreparer texturePreparer = const LiveTexturePreparer(),
    PrismLivePhotoHostApi? hostApi,
  }) : _texturePreparer = texturePreparer,
       _hostApi = hostApi ?? PrismLivePhotoHostApi();

  final LiveTexturePreparer _texturePreparer;
  final PrismLivePhotoHostApi _hostApi;
  String? _activeId;
  void Function(double fraction)? _onProgress;
  int _nextId = 0;

  @override
  Future<LiveExportOutcome> export(
    LiveExport export, {
    required String imageUrl,
    required Color tint,
    required void Function(double fraction) onProgress,
    String? depthMapUrl,
  }) async {
    final String id = 'live-photo-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
    _activeId = id;
    _onProgress = onProgress;
    PrismLivePhotoFlutterApi.setUp(this);
    final List<String> textures = <String>[];
    try {
      if (export.style.needsDepthMap && depthMapUrl == null) {
        return const LiveExportFailed(LiveExportFailure.invalidRequest);
      }
      final double aspect = export.sizePx.width / export.sizePx.height;
      try {
        if (export.style.needsDepthMap) {
          final ({String photo, String depth}) prepared = await _texturePreparer.prepareWithDepth(
            imageUrl,
            depthMapUrl!,
            aspect,
            uniquePaths: true,
          );
          textures.addAll(<String>[prepared.photo, prepared.depth]);
        } else {
          textures.add(await _texturePreparer.prepare(imageUrl, aspect, uniquePaths: true));
        }
      } on LiveTextureException {
        return const LiveExportFailed(LiveExportFailure.sourceUnavailable);
      }
      if (_activeId != id) return const LiveExportCancelled();
      final LivePhotoExportResult result = await _hostApi.exportLivePhoto(
        LivePhotoExportRequest(
          exportId: id,
          photoPath: textures.first,
          depthPath: export.style.needsDepthMap ? textures.last : null,
          style: _pigeonStyle(export.style),
          widthPx: export.sizePx.width.round(),
          heightPx: export.sizePx.height.round(),
          durationMs: export.duration.inMilliseconds,
          framesPerSecond: LiveExport.framesPerSecond,
          tint: tint.toARGB32(),
          timeoutMs: LiveExport.timeLimit.inMilliseconds,
        ),
      );
      if (_activeId != id) return const LiveExportCancelled();
      return outcomeOf(result);
    } catch (error, stackTrace) {
      logger.w('Live Photo export failed', error: error, stackTrace: stackTrace);
      return const LiveExportFailed(LiveExportFailure.unavailable);
    } finally {
      if (_activeId == id) {
        _activeId = null;
        _onProgress = null;
        PrismLivePhotoFlutterApi.setUp(null);
      }
      for (final String path in textures) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> cancel() async {
    final String? id = _activeId;
    _activeId = null;
    _onProgress = null;
    PrismLivePhotoFlutterApi.setUp(null);
    if (id != null) await _cancelNative(id);
  }

  Future<void> _cancelNative(String id) async {
    try {
      await _hostApi.cancelLivePhotoExport(id);
    } catch (error, stackTrace) {
      logger.w('Could not cancel the Live Photo export', error: error, stackTrace: stackTrace);
    }
  }

  @override
  void onLivePhotoExportProgress(String exportId, double fraction) {
    if (exportId == _activeId) _onProgress?.call(fraction.clamp(0.0, 1.0));
  }

  static LivePhotoStyle _pigeonStyle(MotionStyle style) => switch (style) {
    MotionStyle.drift => LivePhotoStyle.drift,
    MotionStyle.breathe => LivePhotoStyle.breathe,
    MotionStyle.shimmer => LivePhotoStyle.shimmer,
    MotionStyle.depth => LivePhotoStyle.depth,
    MotionStyle.ripple => throw ArgumentError.value(style, 'style', 'Ripple has no Live Photo style'),
  };

  static LiveExportOutcome outcomeOf(LivePhotoExportResult result) => switch (result.status) {
    LivePhotoExportStatus.saved => LiveExportSaved(assetId: result.assetId ?? '', verified: result.verifiedLive),
    LivePhotoExportStatus.cancelled => const LiveExportCancelled(),
    LivePhotoExportStatus.permissionDenied => const LiveExportRefused(restricted: false),
    LivePhotoExportStatus.permissionRestricted => const LiveExportRefused(restricted: true),
    LivePhotoExportStatus.timedOut => const LiveExportTimedOut(),
    LivePhotoExportStatus.failed => LiveExportFailed(switch (result.errorCode) {
      'invalid-request' => LiveExportFailure.invalidRequest,
      'render-failed' => LiveExportFailure.renderFailed,
      'save-failed' => LiveExportFailure.saveFailed,
      'not-live' => LiveExportFailure.notLive,
      _ => LiveExportFailure.encodeFailed,
    }),
  };
}
