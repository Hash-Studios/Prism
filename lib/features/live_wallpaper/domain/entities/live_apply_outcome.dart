enum LiveApplyStatus { applied, confirmInPreview, cancelled, failed, unsupported, proRequired }

class LiveApplyOutcome {
  const LiveApplyOutcome(this.status, this.message);

  const LiveApplyOutcome.confirmInPreview() : this(LiveApplyStatus.confirmInPreview, 'Confirm in the system preview.');

  const LiveApplyOutcome.proRequired() : this(LiveApplyStatus.proRequired, 'This style is part of Prism Pro.');

  const LiveApplyOutcome.failed(String message) : this(LiveApplyStatus.failed, message);

  final LiveApplyStatus status;
  final String message;

  bool get isError => status == LiveApplyStatus.failed || status == LiveApplyStatus.unsupported;
}
