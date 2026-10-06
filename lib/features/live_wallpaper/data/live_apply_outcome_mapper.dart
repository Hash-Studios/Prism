import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;

LiveApplyOutcome liveApplyOutcomeFromResult(aw.WallpaperOperationResult result) {
  switch (result.status) {
    case aw.WallpaperOperationStatus.applied:
      return const LiveApplyOutcome(LiveApplyStatus.applied, 'Live wallpaper set.');
    case aw.WallpaperOperationStatus.previewOpened:
    case aw.WallpaperOperationStatus.awaitingUserConfirmation:
      return const LiveApplyOutcome.confirmInPreview();
    case aw.WallpaperOperationStatus.cancelled:
      return const LiveApplyOutcome(LiveApplyStatus.cancelled, '');
    case aw.WallpaperOperationStatus.unsupported:
      return const LiveApplyOutcome(LiveApplyStatus.unsupported, 'This device cannot show live wallpapers.');
    case aw.WallpaperOperationStatus.foregroundRequired:
      return const LiveApplyOutcome.failed('Keep Prism open and try again.');
    case aw.WallpaperOperationStatus.failed:
      return LiveApplyOutcome.failed(_messageForCode(result.errorCode));
  }
}

String _messageForCode(String? code) {
  switch (code) {
    case 'source-too-large':
    case 'image-too-large':
    case 'texture-source-too-large':
      return 'That file is too large for a live wallpaper.';
    case 'texture-dimensions-exceeded':
      return 'That image is too large for a live wallpaper.';
    case 'invalid-video':
    case 'video-preparation-failed':
      return 'That video cannot be played as a wallpaper. Try another clip.';
    case 'source-unavailable':
    case 'texture-source-unavailable':
      return "Couldn't read the file. Try again.";
    case 'permission-denied':
      return 'Prism does not have permission to read that file.';
    case 'out-of-memory':
      return 'Not enough memory. Close other apps and try again.';
    case 'shader-compilation-failed':
    case 'shader-link-failed':
    case 'opengl-configuration-failed':
    case 'egl-unavailable':
    case 'egl-initialization-failed':
      return 'This device could not start that style. Try another one.';
    case 'system-ui-unavailable':
    case 'system-ui-failed':
      return "Couldn't open the system preview.";
    default:
      return "Couldn't set the live wallpaper. Try again.";
  }
}
