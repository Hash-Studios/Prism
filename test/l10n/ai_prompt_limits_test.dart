import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_prompt_pools.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The AI worker clips a prompt to 160 characters, so every suggested prompt must fit.
const int _maxPromptLength = 160;

void main() {
  for (final Locale locale in AppLocalizations.supportedLocales) {
    group('$locale AI prompts', () {
      late AppLocalizations l10n;

      setUpAll(() async => l10n = await loadAppLocalizations(locale));

      test('every random prompt fits the worker limit', () {
        for (final AiStylePreset style in AiStylePreset.values) {
          for (final String scene in AiPromptPools.scenesByStyle(l10n, style)) {
            for (final String lighting in AiPromptPools.lighting(l10n)) {
              for (final String palette in AiPromptPools.palettes(l10n)) {
                final String prompt = l10n.economyAiPromptComposition(
                  scene,
                  lighting,
                  palette,
                  l10n.economyAiPromptSuffix,
                );
                expect(prompt.length, lessThanOrEqualTo(_maxPromptLength), reason: '${style.name}: $prompt');
              }
            }
          }
        }
      });

      test('every scene idea and onboarding prompt fits the worker limit', () {
        for (final AiStylePreset style in AiStylePreset.values) {
          for (int index = 0; index < 3; index++) {
            final String prompt = AiPromptPools.sceneIdea(l10n, style, index);
            expect(prompt.length, lessThanOrEqualTo(_maxPromptLength), reason: '${style.name}: $prompt');
          }
          for (final String prompt in OnboardingV2Config.aiOnboardingPrompts(l10n, style)) {
            expect(prompt.length, lessThanOrEqualTo(_maxPromptLength), reason: '${style.name}: $prompt');
          }
        }
        expect(OnboardingV2Config.aiOnboardingPromptFallback(l10n).length, lessThanOrEqualTo(_maxPromptLength));
      });

      test('every style has 8 different scenes and 5 different onboarding prompts', () {
        for (final AiStylePreset style in AiStylePreset.values) {
          expect(AiPromptPools.scenesByStyle(l10n, style).toSet(), hasLength(8), reason: style.name);
          expect(OnboardingV2Config.aiOnboardingPrompts(l10n, style).toSet(), hasLength(5), reason: style.name);
        }
        expect(AiPromptPools.lighting(l10n).toSet(), hasLength(8));
        expect(AiPromptPools.palettes(l10n).toSet(), hasLength(8));
      });
    });
  }
}
