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

  test('random prompt combines the selected scene with localized prompt details', () {
    final prompt = AiPromptPools.randomPrompt(l10n, AiStylePreset.anime, _FirstIndexRandom());

    expect(
      prompt,
      'an anime skyline above floating islands, soft ambient lighting, calm mood, high detail, '
      'vertical phone wallpaper, no text',
    );
  });

  test('scene ideas cycle through the first three scenes and add the wallpaper instructions', () {
    expect(
      AiPromptPools.sceneIdea(l10n, AiStylePreset.nature, 0),
      'a misty mountain range at sunrise, vertical phone wallpaper, no text',
    );
    expect(
      AiPromptPools.sceneIdea(l10n, AiStylePreset.nature, 2),
      'a dramatic coastal cliff with crashing waves, vertical phone wallpaper, no text',
    );
    expect(
      AiPromptPools.sceneIdea(l10n, AiStylePreset.nature, 3),
      'a misty mountain range at sunrise, vertical phone wallpaper, no text',
    );
  });
}
