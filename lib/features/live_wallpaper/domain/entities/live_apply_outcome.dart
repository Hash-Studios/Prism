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
  const LiveApplyOutcome(this.status, {this.failure});

  const LiveApplyOutcome.confirmInPreview() : this(LiveApplyStatus.confirmInPreview);

  const LiveApplyOutcome.proRequired() : this(LiveApplyStatus.proRequired);

  const LiveApplyOutcome.failed(LiveApplyFailure failure) : this(LiveApplyStatus.failed, failure: failure);

  final LiveApplyStatus status;
  final LiveApplyFailure? failure;

  bool get isError => status == LiveApplyStatus.failed || status == LiveApplyStatus.unsupported;
}
