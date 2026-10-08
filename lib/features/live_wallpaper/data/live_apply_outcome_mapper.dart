import 'package:Prism/core/platform/wallpaper_error_messages.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;

export 'package:Prism/core/platform/wallpaper_error_messages.dart';

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
      return LiveApplyOutcome.failed(wallpaperErrorMessage(result.errorCode, live: true));
  }
}
