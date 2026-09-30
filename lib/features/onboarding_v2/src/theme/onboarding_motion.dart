/// Motion that belongs to the onboarding welcome art only. Everything else uses `PrismDurations` and `PrismCurves`.
class OnboardingMotion {
  const OnboardingMotion._();

  /// How long the welcome art takes to settle from a slight zoom.
  static const Duration backgroundReveal = Duration(seconds: 2);
}
