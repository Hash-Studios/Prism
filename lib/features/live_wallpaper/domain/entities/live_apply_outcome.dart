import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_screens.dart';

enum LiveApplyStatus { applied, confirmInPreview, cancelled, failed, unsupported, proRequired }

enum LiveApplyFailure {
  setFailed,
  keepPrismOpen,
  textureDownloadFailed,
  texturePreparationFailed,
  textureTooDetailed,
  videoReadFailed,
  videoTooLarge,
  fileTooLarge,
  imageTooLarge,
  imageTooLargeForDevice,
  wallpaperNotAllowed,
  outOfMemory,
  timeout,
  invalidVideo,
  sourceUnavailable,
  permissionDenied,
  styleUnavailable,
  systemPreviewUnavailable,
}

class LiveApplyOutcome {
  const LiveApplyOutcome(this.status, {this.failure, this.target, this.fallback = false, this.screens});

  const LiveApplyOutcome.confirmInPreview({WallpaperTarget? target, bool fallback = false})
    : this(LiveApplyStatus.confirmInPreview, target: target, fallback: fallback);

  const LiveApplyOutcome.proRequired() : this(LiveApplyStatus.proRequired);

  const LiveApplyOutcome.failed(LiveApplyFailure failure) : this(LiveApplyStatus.failed, failure: failure);

  /// The user confirmed in the system preview, and [target] now shows the new live wall.
  const LiveApplyOutcome.screensSet({required WallpaperTarget target, required LiveScreens screens})
    : this(LiveApplyStatus.applied, target: target, screens: screens);

  final LiveApplyStatus status;
  final LiveApplyFailure? failure;

  /// The screens the user asked for. With [screens], the screens that got the new wall.
  final WallpaperTarget? target;

  /// This Android version shares one live wall between both screens, whatever [target] was.
  final bool fallback;

  /// What each screen shows, read back after a per-screen apply.
  final LiveScreens? screens;

  bool get isError => status == LiveApplyStatus.failed || status == LiveApplyStatus.unsupported;
}
