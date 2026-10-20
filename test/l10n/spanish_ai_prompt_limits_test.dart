import 'dart:math';

import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_prompt_pools.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueuedIndexRandom implements Random {
  _QueuedIndexRandom(this._indices);

  final List<int> _indices;

  @override
  int nextInt(int max) {
    expect(max, 5, reason: 'Update the exhaustive matrix when a prompt pool changes size.');
    return _indices.removeAt(0);
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  final l10n = AppLocalizationsEs();

  test('every Spanish random AI prompt stays within 160 UTF-16 code units', () {
    for (final style in AiStylePreset.values) {
      for (var scene = 0; scene < 5; scene++) {
        for (var lighting = 0; lighting < 5; lighting++) {
          for (var mood = 0; mood < 5; mood++) {
            for (var quality = 0; quality < 5; quality++) {
              final prompt = AiPromptPools.randomPrompt(
                l10n,
                style,
                _QueuedIndexRandom(<int>[scene, lighting, mood, quality]),
              );

              expect(
                prompt.length,
                lessThanOrEqualTo(160),
                reason: '${style.name}: ${prompt.length} UTF-16 code units: $prompt',
              );
            }
          }
        }
      }
    }
  });

  test('every Spanish scene idea and onboarding AI prompt stays within 160 UTF-16 code units', () {
    for (final style in AiStylePreset.values) {
      for (var scene = 0; scene < 3; scene++) {
        final prompt = AiPromptPools.sceneIdea(l10n, style, scene);

        expect(
          prompt.length,
          lessThanOrEqualTo(160),
          reason: '${style.name} scene $scene: ${prompt.length} UTF-16 code units: $prompt',
        );
      }

      for (final prompt in OnboardingV2Config.aiOnboardingPrompts(l10n, style)) {
        expect(
          prompt.length,
          lessThanOrEqualTo(160),
          reason: '${style.name} onboarding prompt: ${prompt.length} UTF-16 code units: $prompt',
        );
      }
    }

    final fallback = OnboardingV2Config.aiOnboardingPromptFallback(l10n);
    expect(
      fallback.length,
      lessThanOrEqualTo(160),
      reason: 'onboarding fallback: ${fallback.length} UTF-16 code units: $fallback',
    );
  });
}
