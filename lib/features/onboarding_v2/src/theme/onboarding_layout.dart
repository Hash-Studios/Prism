class OnboardingLayout {
  const OnboardingLayout._();

  static const double designWidth = 393;
  static const double designHeight = 852;

  /// Content never grows wider than this, so a tablet or a landscape phone keeps a phone-shaped column.
  static const double maxContentWidth = 480;

  /// Below this frame height at 1x text the fixed layout would overlap, so the page scrolls instead.
  static const double minFrameHeight = 760;

  /// The layout is built and checked up to this text scale; larger system scales are held here.
  static const double maxTextScale = 1.3;

  static const double ctaX = 32;
  static const double ctaY = 721;
  static const double ctaHeight = 64;

  static const double welcomeLogoY = 54;

  static const double welcomeHeadlineY = 419;

  static const double welcomeBodyY = 535;

  static const double stepTitleY = 100;
  static const double proBadgeY = 184;
  static const double interestsTitleX = 10;
  static const double starterPackTitleX = 10;
  static const double aiTitleX = 10;

  static const double progressY = 63;
  static const double progressWidth = 56;
  static const double progressHeight = 8;

  static const double skipX = 332;
  static const double skipY = 56;

  static const double tilesX = 27;
  static const double tilesY = 163;
  static const double tilesHeight = 536;
  static const double tileSize = 164;
  static const double tileGap = 12;

  static const double creatorsX = 27;
  static const double creatorsY = 163;
  static const double creatorHeight = 164;
  static const double creatorGap = 12;

  static const double helperY = 811;

  static const double progressDotSize = 8;
  static const double progressActiveWidth = 24;
  static const double progressStepSpacing = 16;

  static const double loadingIndicatorSize = 18;
  static const double loadingIndicatorStroke = 2.2;

  // AI generation step content (below the two-line headline at stepTitleY=100)
  static const double aiChipX = 27;
  static const double aiChipY = 216;
  static const double aiPreviewX = 27;
  static const double aiPreviewY = 298;

  static const double softenedBlurSigma = 100;
}
