import 'dart:math';

import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_prompt_pools.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

class _FirstIndexRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  final l10n = AppLocalizationsEn();

  test('random prompt combines the selected scene with a lighting and a palette', () {
    final prompt = AiPromptPools.randomPrompt(l10n, AiStylePreset.anime, _FirstIndexRandom());

    expect(
      prompt,
      'a cat napping on a sunlit train platform, soft morning haze, teal and amber hues, '
      'vertical phone wallpaper, no text',
    );
  });

  test('random prompts use the scenes of the new styles', () {
    expect(
      AiPromptPools.randomPrompt(l10n, AiStylePreset.ukiyoE, _FirstIndexRandom()),
      startsWith('a great wave curling beneath a pale moon, '),
    );
  });

  test('scene ideas cycle through the first three scenes and add the wallpaper instructions', () {
    expect(
      AiPromptPools.sceneIdea(l10n, AiStylePreset.nature, 0),
      'a waterfall pouring into a mossy gorge, vertical phone wallpaper, no text',
    );
    expect(
      AiPromptPools.sceneIdea(l10n, AiStylePreset.nature, 2),
      'a frozen lake with cracks of blue ice, vertical phone wallpaper, no text',
    );
    expect(
      AiPromptPools.sceneIdea(l10n, AiStylePreset.nature, 3),
      'a waterfall pouring into a mossy gorge, vertical phone wallpaper, no text',
    );
  });

  test('scenes do not repeat across styles', () {
    final List<String> scenes = <String>[
      for (final AiStylePreset style in AiStylePreset.values) ...AiPromptPools.scenesByStyle(l10n, style),
    ];
    expect(scenes.toSet(), hasLength(scenes.length));
  });
}
