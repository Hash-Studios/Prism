import 'dart:math';

import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';

/// Example scenes and modifiers that seed and shuffle the prompt field.
// ignore: avoid_classes_with_only_static_members
abstract final class AiPromptPools {
  static List<String> scenesByStyle(AppLocalizations l10n, AiStylePreset style) => switch (style) {
    AiStylePreset.anime => <String>[
      l10n.economyAiPromptSceneAnime1,
      l10n.economyAiPromptSceneAnime2,
      l10n.economyAiPromptSceneAnime3,
      l10n.economyAiPromptSceneAnime4,
      l10n.economyAiPromptSceneAnime5,
    ],
    AiStylePreset.minimal => <String>[
      l10n.economyAiPromptSceneMinimal1,
      l10n.economyAiPromptSceneMinimal2,
      l10n.economyAiPromptSceneMinimal3,
      l10n.economyAiPromptSceneMinimal4,
      l10n.economyAiPromptSceneMinimal5,
    ],
    AiStylePreset.cyberpunk => <String>[
      l10n.economyAiPromptSceneCyberpunk1,
      l10n.economyAiPromptSceneCyberpunk2,
      l10n.economyAiPromptSceneCyberpunk3,
      l10n.economyAiPromptSceneCyberpunk4,
      l10n.economyAiPromptSceneCyberpunk5,
    ],
    AiStylePreset.watercolor => <String>[
      l10n.economyAiPromptSceneWatercolor1,
      l10n.economyAiPromptSceneWatercolor2,
      l10n.economyAiPromptSceneWatercolor3,
      l10n.economyAiPromptSceneWatercolor4,
      l10n.economyAiPromptSceneWatercolor5,
    ],
    AiStylePreset.meshGradient => <String>[
      l10n.economyAiPromptSceneMeshGradient1,
      l10n.economyAiPromptSceneMeshGradient2,
      l10n.economyAiPromptSceneMeshGradient3,
      l10n.economyAiPromptSceneMeshGradient4,
      l10n.economyAiPromptSceneMeshGradient5,
    ],
    AiStylePreset.abstract => <String>[
      l10n.economyAiPromptSceneAbstract1,
      l10n.economyAiPromptSceneAbstract2,
      l10n.economyAiPromptSceneAbstract3,
      l10n.economyAiPromptSceneAbstract4,
      l10n.economyAiPromptSceneAbstract5,
    ],
    AiStylePreset.nature => <String>[
      l10n.economyAiPromptSceneNature1,
      l10n.economyAiPromptSceneNature2,
      l10n.economyAiPromptSceneNature3,
      l10n.economyAiPromptSceneNature4,
      l10n.economyAiPromptSceneNature5,
    ],
  };

  static List<String> _lighting(AppLocalizations l10n) => <String>[
    l10n.economyAiPromptLightingSoftAmbient,
    l10n.economyAiPromptLightingCinematicRim,
    l10n.economyAiPromptLightingGoldenHour,
    l10n.economyAiPromptLightingMoonlit,
    l10n.economyAiPromptLightingVolumetric,
  ];

  static List<String> _moods(AppLocalizations l10n) => <String>[
    l10n.economyAiPromptMoodCalm,
    l10n.economyAiPromptMoodDreamy,
    l10n.economyAiPromptMoodEpic,
    l10n.economyAiPromptMoodMoody,
    l10n.economyAiPromptMoodUplifting,
  ];

  static List<String> _qualities(AppLocalizations l10n) => <String>[
    l10n.economyAiPromptQualityHighDetail,
    l10n.economyAiPromptQualityCleanComposition,
    l10n.economyAiPromptQualityCrispTextures,
    l10n.economyAiPromptQualityBalancedContrast,
    l10n.economyAiPromptQualityNaturalColors,
  ];

  static String _pick(Random random, List<String> values) => values[random.nextInt(values.length)];

  /// A full example prompt for [style].
  static String randomPrompt(AppLocalizations l10n, AiStylePreset style, Random random) =>
      l10n.economyAiPromptComposition(
        _pick(random, scenesByStyle(l10n, style)),
        _pick(random, _lighting(l10n)),
        _pick(random, _moods(l10n)),
        _pick(random, _qualities(l10n)),
        l10n.economyAiPromptSuffix,
      );

  /// The scene at [index] in [style]'s first three ideas, wrapped into a prompt.
  static String sceneIdea(AppLocalizations l10n, AiStylePreset style, int index) {
    final List<String> scenes = scenesByStyle(l10n, style).take(3).toList();
    return l10n.economyAiPromptSceneOnly(scenes[index % scenes.length], l10n.economyAiPromptSuffix);
  }
}
