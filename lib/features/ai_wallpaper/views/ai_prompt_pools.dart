import 'dart:math';

import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';

/// Example scenes, lighting and palettes that seed and shuffle the prompt field.
// ignore: avoid_classes_with_only_static_members
abstract final class AiPromptPools {
  static List<String> scenesByStyle(AppLocalizations l10n, AiStylePreset style) => switch (style) {
    AiStylePreset.anime => <String>[
      l10n.economyAiPromptSceneAnime1,
      l10n.economyAiPromptSceneAnime2,
      l10n.economyAiPromptSceneAnime3,
      l10n.economyAiPromptSceneAnime4,
      l10n.economyAiPromptSceneAnime5,
      l10n.economyAiPromptSceneAnime6,
      l10n.economyAiPromptSceneAnime7,
      l10n.economyAiPromptSceneAnime8,
    ],
    AiStylePreset.minimal => <String>[
      l10n.economyAiPromptSceneMinimal1,
      l10n.economyAiPromptSceneMinimal2,
      l10n.economyAiPromptSceneMinimal3,
      l10n.economyAiPromptSceneMinimal4,
      l10n.economyAiPromptSceneMinimal5,
      l10n.economyAiPromptSceneMinimal6,
      l10n.economyAiPromptSceneMinimal7,
      l10n.economyAiPromptSceneMinimal8,
    ],
    AiStylePreset.cyberpunk => <String>[
      l10n.economyAiPromptSceneCyberpunk1,
      l10n.economyAiPromptSceneCyberpunk2,
      l10n.economyAiPromptSceneCyberpunk3,
      l10n.economyAiPromptSceneCyberpunk4,
      l10n.economyAiPromptSceneCyberpunk5,
      l10n.economyAiPromptSceneCyberpunk6,
      l10n.economyAiPromptSceneCyberpunk7,
      l10n.economyAiPromptSceneCyberpunk8,
    ],
    AiStylePreset.watercolor => <String>[
      l10n.economyAiPromptSceneWatercolor1,
      l10n.economyAiPromptSceneWatercolor2,
      l10n.economyAiPromptSceneWatercolor3,
      l10n.economyAiPromptSceneWatercolor4,
      l10n.economyAiPromptSceneWatercolor5,
      l10n.economyAiPromptSceneWatercolor6,
      l10n.economyAiPromptSceneWatercolor7,
      l10n.economyAiPromptSceneWatercolor8,
    ],
    AiStylePreset.meshGradient => <String>[
      l10n.economyAiPromptSceneMeshGradient1,
      l10n.economyAiPromptSceneMeshGradient2,
      l10n.economyAiPromptSceneMeshGradient3,
      l10n.economyAiPromptSceneMeshGradient4,
      l10n.economyAiPromptSceneMeshGradient5,
      l10n.economyAiPromptSceneMeshGradient6,
      l10n.economyAiPromptSceneMeshGradient7,
      l10n.economyAiPromptSceneMeshGradient8,
    ],
    AiStylePreset.abstract => <String>[
      l10n.economyAiPromptSceneAbstract1,
      l10n.economyAiPromptSceneAbstract2,
      l10n.economyAiPromptSceneAbstract3,
      l10n.economyAiPromptSceneAbstract4,
      l10n.economyAiPromptSceneAbstract5,
      l10n.economyAiPromptSceneAbstract6,
      l10n.economyAiPromptSceneAbstract7,
      l10n.economyAiPromptSceneAbstract8,
    ],
    AiStylePreset.nature => <String>[
      l10n.economyAiPromptSceneNature1,
      l10n.economyAiPromptSceneNature2,
      l10n.economyAiPromptSceneNature3,
      l10n.economyAiPromptSceneNature4,
      l10n.economyAiPromptSceneNature5,
      l10n.economyAiPromptSceneNature6,
      l10n.economyAiPromptSceneNature7,
      l10n.economyAiPromptSceneNature8,
    ],
    AiStylePreset.space => <String>[
      l10n.economyAiPromptSceneSpace1,
      l10n.economyAiPromptSceneSpace2,
      l10n.economyAiPromptSceneSpace3,
      l10n.economyAiPromptSceneSpace4,
      l10n.economyAiPromptSceneSpace5,
      l10n.economyAiPromptSceneSpace6,
      l10n.economyAiPromptSceneSpace7,
      l10n.economyAiPromptSceneSpace8,
    ],
    AiStylePreset.synthwave => <String>[
      l10n.economyAiPromptSceneSynthwave1,
      l10n.economyAiPromptSceneSynthwave2,
      l10n.economyAiPromptSceneSynthwave3,
      l10n.economyAiPromptSceneSynthwave4,
      l10n.economyAiPromptSceneSynthwave5,
      l10n.economyAiPromptSceneSynthwave6,
      l10n.economyAiPromptSceneSynthwave7,
      l10n.economyAiPromptSceneSynthwave8,
    ],
    AiStylePreset.pixelArt => <String>[
      l10n.economyAiPromptScenePixelArt1,
      l10n.economyAiPromptScenePixelArt2,
      l10n.economyAiPromptScenePixelArt3,
      l10n.economyAiPromptScenePixelArt4,
      l10n.economyAiPromptScenePixelArt5,
      l10n.economyAiPromptScenePixelArt6,
      l10n.economyAiPromptScenePixelArt7,
      l10n.economyAiPromptScenePixelArt8,
    ],
    AiStylePreset.render3d => <String>[
      l10n.economyAiPromptSceneRender3d1,
      l10n.economyAiPromptSceneRender3d2,
      l10n.economyAiPromptSceneRender3d3,
      l10n.economyAiPromptSceneRender3d4,
      l10n.economyAiPromptSceneRender3d5,
      l10n.economyAiPromptSceneRender3d6,
      l10n.economyAiPromptSceneRender3d7,
      l10n.economyAiPromptSceneRender3d8,
    ],
    AiStylePreset.oilPainting => <String>[
      l10n.economyAiPromptSceneOilPainting1,
      l10n.economyAiPromptSceneOilPainting2,
      l10n.economyAiPromptSceneOilPainting3,
      l10n.economyAiPromptSceneOilPainting4,
      l10n.economyAiPromptSceneOilPainting5,
      l10n.economyAiPromptSceneOilPainting6,
      l10n.economyAiPromptSceneOilPainting7,
      l10n.economyAiPromptSceneOilPainting8,
    ],
    AiStylePreset.ukiyoE => <String>[
      l10n.economyAiPromptSceneUkiyoE1,
      l10n.economyAiPromptSceneUkiyoE2,
      l10n.economyAiPromptSceneUkiyoE3,
      l10n.economyAiPromptSceneUkiyoE4,
      l10n.economyAiPromptSceneUkiyoE5,
      l10n.economyAiPromptSceneUkiyoE6,
      l10n.economyAiPromptSceneUkiyoE7,
      l10n.economyAiPromptSceneUkiyoE8,
    ],
  };

  @visibleForTesting
  static List<String> lighting(AppLocalizations l10n) => <String>[
    l10n.economyAiPromptLightingMorningHaze,
    l10n.economyAiPromptLightingGoldenHour,
    l10n.economyAiPromptLightingMoonlight,
    l10n.economyAiPromptLightingNeonRim,
    l10n.economyAiPromptLightingBacklight,
    l10n.economyAiPromptLightingGodRays,
    l10n.economyAiPromptLightingStudio,
    l10n.economyAiPromptLightingTwilight,
  ];

  @visibleForTesting
  static List<String> palettes(AppLocalizations l10n) => <String>[
    l10n.economyAiPromptPaletteTealAmber,
    l10n.economyAiPromptPaletteIndigoRose,
    l10n.economyAiPromptPaletteSageCream,
    l10n.economyAiPromptPaletteBlackNeonPink,
    l10n.economyAiPromptPalettePastelPeach,
    l10n.economyAiPromptPaletteEmeraldGold,
    l10n.economyAiPromptPaletteOceanBlue,
    l10n.economyAiPromptPaletteCrimsonCharcoal,
  ];

  static String _pick(Random random, List<String> values) => values[random.nextInt(values.length)];

  /// A full example prompt for [style].
  static String randomPrompt(AppLocalizations l10n, AiStylePreset style, Random random) =>
      l10n.economyAiPromptComposition(
        _pick(random, scenesByStyle(l10n, style)),
        _pick(random, lighting(l10n)),
        _pick(random, palettes(l10n)),
        l10n.economyAiPromptSuffix,
      );

  /// The scene at [index] in [style]'s first three ideas, wrapped into a prompt.
  static String sceneIdea(AppLocalizations l10n, AiStylePreset style, int index) {
    final List<String> scenes = scenesByStyle(l10n, style).take(3).toList();
    return l10n.economyAiPromptSceneOnly(scenes[index % scenes.length], l10n.economyAiPromptSuffix);
  }
}
