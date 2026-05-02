import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';

class OnboardingV2Config {
  const OnboardingV2Config._();

  /// Set to true locally to force onboarding for already-onboarded accounts.
  /// NEVER commit as true.
  static const bool debugForceOnboarding = false;

  static const int minInterests = 3;
  static const int minFollows = 3;
  static const int paywallSoftGateSeconds = 4;
  static const int targetCreatorsCount = 10;
  static const int firstWallpaperValueTargetMs = 60000;

  static const String paywallPlacement = 'onboarding_completion';
  static const String paywallSource = 'onboarding_v2_last_step';
  static const String remoteConfigStarterPackKey = 'onboarding_starter_pack_v1';
  static const String remoteConfigV2EnabledKey = 'onboarding_v2_enabled';
  static const String excludedCategory = 'Community';

  // ---------------------------------------------------------------------------
  // AI generation step — onboarding free generation
  // ---------------------------------------------------------------------------

  static const List<AiStylePreset> aiOnboardingStyles = [
    AiStylePreset.nature,
    AiStylePreset.abstract,
    AiStylePreset.watercolor,
    AiStylePreset.minimal,
    AiStylePreset.cyberpunk,
  ];

  /// Maps lowercase interest-category keywords to the best-matching AI style.
  /// Keyword matching is done with `contains`, so partial names work too.
  static const Map<String, AiStylePreset> aiInterestStyleMap = {
    'nature': AiStylePreset.nature,
    'landscape': AiStylePreset.nature,
    'forest': AiStylePreset.nature,
    'mountain': AiStylePreset.nature,
    'floral': AiStylePreset.nature,
    'botanical': AiStylePreset.nature,
    'ocean': AiStylePreset.nature,
    'beach': AiStylePreset.nature,
    'anime': AiStylePreset.anime,
    'manga': AiStylePreset.anime,
    'illustration': AiStylePreset.anime,
    'minimal': AiStylePreset.minimal,
    'clean': AiStylePreset.minimal,
    'simple': AiStylePreset.minimal,
    'monochrome': AiStylePreset.minimal,
    'black': AiStylePreset.minimal,
    'white': AiStylePreset.minimal,
    'cyberpunk': AiStylePreset.cyberpunk,
    'neon': AiStylePreset.cyberpunk,
    'tech': AiStylePreset.cyberpunk,
    'city': AiStylePreset.cyberpunk,
    'urban': AiStylePreset.cyberpunk,
    'futuristic': AiStylePreset.cyberpunk,
    'watercolor': AiStylePreset.watercolor,
    'paint': AiStylePreset.watercolor,
    'pastel': AiStylePreset.watercolor,
    'art': AiStylePreset.watercolor,
    'gradient': AiStylePreset.meshGradient,
    'colorful': AiStylePreset.meshGradient,
    'vibrant': AiStylePreset.meshGradient,
    'abstract': AiStylePreset.abstract,
    'digital': AiStylePreset.abstract,
    'geometric': AiStylePreset.abstract,
    'space': AiStylePreset.abstract,
    'dark': AiStylePreset.abstract,
  };

  static const Map<AiStylePreset, List<String>> aiOnboardingPromptPool = {
    AiStylePreset.nature: [
      'a misty mountain range at sunrise with warm golden light',
      'a dense evergreen forest with sun rays breaking through the canopy',
      'a dramatic coastal cliff with crashing waves and moody sky',
      'a calm alpine lake under a twilight sky with star reflections',
      'a desert canyon with warm golden light and dramatic rock formations',
    ],
    AiStylePreset.abstract: [
      'an abstract fractal composition with dynamic curves and vivid color',
      'layered liquid forms with modern depth and metallic sheen',
      'bold abstract shapes with soft edges and cinematic contrast',
      'a surreal abstract field of floating geometry bathed in neon light',
      'organic abstract waves with rich texture and depth of field',
    ],
    AiStylePreset.watercolor: [
      'a watercolor forest valley at dawn with soft pastel mist',
      'a hand-painted mountain lake scene in dreamy watercolor tones',
      'soft watercolor clouds above rolling hills at golden hour',
      'a tranquil riverbank with pastel watercolor reflections',
      'an artistic watercolor coastline at sunset with warm hues',
    ],
    AiStylePreset.minimal: [
      'minimal sand dunes and a single sun disk on the horizon',
      'clean geometric mountain layers in soft muted tones',
      'a serene monochrome ocean horizon at dusk',
      'simple abstract lines with perfectly balanced negative space',
      'a soft gradient sky over flat minimalist hills',
    ],
    AiStylePreset.cyberpunk: [
      'a neon megacity street with wet reflections and flying vehicles',
      'a futuristic alley with holographic billboards and teal-magenta light',
      'a high-tech skyline at night with glowing traffic lanes',
      'a cyberpunk rooftop overlooking a city of glowing towers',
      'a midnight city crossing drenched in teal and magenta neon',
    ],
  };
}
