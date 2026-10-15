/// Size limits for the onboarding steps. The steps reflow, so these only cap how far they stretch.
class OnboardingLayout {
  const OnboardingLayout._();

  /// Content never grows wider than this, so a tablet or a landscape phone keeps a phone-shaped column.
  static const double maxContentWidth = 480;

  /// System text above this scale is held here. The steps stay usable up to it with room to spare.
  static const double maxTextScale = 1.3;
}
