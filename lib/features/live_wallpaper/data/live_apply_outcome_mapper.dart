import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;

export 'package:Prism/core/platform/wallpaper_error_messages.dart';

LiveApplyFailure _failureForCode(String? code) => switch (code) {
  'source-too-large' || 'texture-source-too-large' => LiveApplyFailure.fileTooLarge,
  'image-too-large' => LiveApplyFailure.imageTooLarge,
  'texture-dimensions-exceeded' => LiveApplyFailure.imageTooLarge,
  'wallpaper-not-allowed' => LiveApplyFailure.wallpaperNotAllowed,
  'out-of-memory' => LiveApplyFailure.outOfMemory,
  'timeout' => LiveApplyFailure.timeout,
  'invalid-video' || 'video-preparation-failed' => LiveApplyFailure.invalidVideo,
  'source-unavailable' || 'texture-source-unavailable' => LiveApplyFailure.sourceUnavailable,
  'permission-denied' => LiveApplyFailure.permissionDenied,
  'shader-compilation-failed' ||
  'shader-link-failed' ||
  'opengl-configuration-failed' ||
  'egl-unavailable' ||
  'egl-initialization-failed' => LiveApplyFailure.styleUnavailable,
  'system-ui-unavailable' || 'system-ui-failed' => LiveApplyFailure.systemPreviewUnavailable,
  _ => LiveApplyFailure.setFailed,
};

LiveApplyOutcome liveApplyOutcomeFromResult(aw.WallpaperOperationResult result) {
  switch (result.status) {
    case aw.WallpaperOperationStatus.applied:
      return const LiveApplyOutcome(LiveApplyStatus.applied);
    case aw.WallpaperOperationStatus.previewOpened:
    case aw.WallpaperOperationStatus.awaitingUserConfirmation:
      return const LiveApplyOutcome.confirmInPreview();
    case aw.WallpaperOperationStatus.cancelled:
      return const LiveApplyOutcome(LiveApplyStatus.cancelled);
    case aw.WallpaperOperationStatus.unsupported:
      return const LiveApplyOutcome(LiveApplyStatus.unsupported);
    case aw.WallpaperOperationStatus.foregroundRequired:
      return const LiveApplyOutcome.failed(LiveApplyFailure.keepPrismOpen);
    case aw.WallpaperOperationStatus.failed:
      return LiveApplyOutcome.failed(_failureForCode(result.errorCode));
  }
}
