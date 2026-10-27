import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';

class OnboardingV2Config {
  const OnboardingV2Config._();

  /// Set to true locally to force onboarding for already-onboarded accounts.
  /// NEVER commit as true.
  static const bool debugForceOnboarding = false;

  static const int minInterests = 3;
  static const int minFollows = 3;

  static const String paywallPlacement = 'onboarding_completion';
  static const String paywallSource = 'onboarding_v2_last_step';
  static const String remoteConfigStarterPackKey = 'onboarding_starter_pack_v1';
  static const String excludedCategory = 'Community';
  static const String termsUrl = 'https://prismwalls.com/terms';
  static const String privacyUrl = 'https://prismwalls.com/privacy';

  /// Local prefs key: has the user ever ticked the Terms and Privacy policy checkbox?
  static const String termsAcceptedKey = 'onboarding_terms_accepted';

  static const List<AiStylePreset> aiOnboardingStyles = [
    AiStylePreset.nature,
    AiStylePreset.abstract,
    AiStylePreset.watercolor,
    AiStylePreset.minimal,
    AiStylePreset.cyberpunk,
    AiStylePreset.space,
    AiStylePreset.render3d,
  ];

  /// Maps lowercase interest-category keywords to the best-matching AI style.
  /// Keyword matching is done with `contains`, so partial names work too.
  static const Map<String, AiStylePreset> aiInterestStyleMap = {
    'space': AiStylePreset.space,
    'galaxy': AiStylePreset.space,
    'retro': AiStylePreset.synthwave,
    'vintage': AiStylePreset.oilPainting,
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
    'dark': AiStylePreset.abstract,
  };

  static List<String> aiOnboardingPrompts(AppLocalizations l10n, AiStylePreset style) => switch (style) {
    AiStylePreset.nature => <String>[
      l10n.onboardingAiPromptNature1,
      l10n.onboardingAiPromptNature2,
      l10n.onboardingAiPromptNature3,
      l10n.onboardingAiPromptNature4,
      l10n.onboardingAiPromptNature5,
    ],
    AiStylePreset.abstract => <String>[
      l10n.onboardingAiPromptAbstract1,
      l10n.onboardingAiPromptAbstract2,
      l10n.onboardingAiPromptAbstract3,
      l10n.onboardingAiPromptAbstract4,
      l10n.onboardingAiPromptAbstract5,
    ],
    AiStylePreset.watercolor => <String>[
      l10n.onboardingAiPromptWatercolor1,
      l10n.onboardingAiPromptWatercolor2,
      l10n.onboardingAiPromptWatercolor3,
      l10n.onboardingAiPromptWatercolor4,
      l10n.onboardingAiPromptWatercolor5,
    ],
    AiStylePreset.minimal => <String>[
      l10n.onboardingAiPromptMinimal1,
      l10n.onboardingAiPromptMinimal2,
      l10n.onboardingAiPromptMinimal3,
      l10n.onboardingAiPromptMinimal4,
      l10n.onboardingAiPromptMinimal5,
    ],
    AiStylePreset.anime => <String>[
      l10n.onboardingAiPromptAnime1,
      l10n.onboardingAiPromptAnime2,
      l10n.onboardingAiPromptAnime3,
      l10n.onboardingAiPromptAnime4,
      l10n.onboardingAiPromptAnime5,
    ],
    AiStylePreset.meshGradient => <String>[
      l10n.onboardingAiPromptMeshGradient1,
      l10n.onboardingAiPromptMeshGradient2,
      l10n.onboardingAiPromptMeshGradient3,
      l10n.onboardingAiPromptMeshGradient4,
      l10n.onboardingAiPromptMeshGradient5,
    ],
    AiStylePreset.cyberpunk => <String>[
      l10n.onboardingAiPromptCyberpunk1,
      l10n.onboardingAiPromptCyberpunk2,
      l10n.onboardingAiPromptCyberpunk3,
      l10n.onboardingAiPromptCyberpunk4,
      l10n.onboardingAiPromptCyberpunk5,
    ],
    AiStylePreset.space => <String>[
      l10n.onboardingAiPromptSpace1,
      l10n.onboardingAiPromptSpace2,
      l10n.onboardingAiPromptSpace3,
      l10n.onboardingAiPromptSpace4,
      l10n.onboardingAiPromptSpace5,
    ],
    AiStylePreset.synthwave => <String>[
      l10n.onboardingAiPromptSynthwave1,
      l10n.onboardingAiPromptSynthwave2,
      l10n.onboardingAiPromptSynthwave3,
      l10n.onboardingAiPromptSynthwave4,
      l10n.onboardingAiPromptSynthwave5,
    ],
    AiStylePreset.pixelArt => <String>[
      l10n.onboardingAiPromptPixelArt1,
      l10n.onboardingAiPromptPixelArt2,
      l10n.onboardingAiPromptPixelArt3,
      l10n.onboardingAiPromptPixelArt4,
      l10n.onboardingAiPromptPixelArt5,
    ],
    AiStylePreset.render3d => <String>[
      l10n.onboardingAiPromptRender3d1,
      l10n.onboardingAiPromptRender3d2,
      l10n.onboardingAiPromptRender3d3,
      l10n.onboardingAiPromptRender3d4,
      l10n.onboardingAiPromptRender3d5,
    ],
    AiStylePreset.oilPainting => <String>[
      l10n.onboardingAiPromptOilPainting1,
      l10n.onboardingAiPromptOilPainting2,
      l10n.onboardingAiPromptOilPainting3,
      l10n.onboardingAiPromptOilPainting4,
      l10n.onboardingAiPromptOilPainting5,
    ],
    AiStylePreset.ukiyoE => <String>[
      l10n.onboardingAiPromptUkiyoE1,
      l10n.onboardingAiPromptUkiyoE2,
      l10n.onboardingAiPromptUkiyoE3,
      l10n.onboardingAiPromptUkiyoE4,
      l10n.onboardingAiPromptUkiyoE5,
    ],
  };

  static String aiOnboardingPromptFallback(AppLocalizations l10n) => l10n.onboardingAiPromptFallback;
}
