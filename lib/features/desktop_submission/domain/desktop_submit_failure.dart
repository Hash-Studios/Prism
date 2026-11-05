enum DesktopSubmitFailure {
  notLandscape,
  wrongAspect,
  tooSmall,
  unreadable,
  tooLarge,
  alreadyPending,
  notAllowed,
  rateLimited,
  failed,
}

class DesktopSubmitException implements Exception {
  const DesktopSubmitException(this.failure);

  final DesktopSubmitFailure failure;

  @override
  String toString() => 'DesktopSubmitException(${failure.name})';
}
