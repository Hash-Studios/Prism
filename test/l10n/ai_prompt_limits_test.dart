import 'dart:math';

import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_prompt_pools.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The AI worker clips a prompt to 160 UTF-16 code units, so every suggested prompt must fit.
const int _maxPromptLength = 160;

void main() {
  for (final Locale locale in AppLocalizations.supportedLocales) {
    group('$locale AI prompts', () {
      late AppLocalizations l10n;

      setUpAll(() async => l10n = await loadAppLocalizations(locale));

      test('every random prompt fits the worker limit', () {
        for (final AiStylePreset style in AiStylePreset.values) {
          final List<String> scenes = AiPromptPools.scenesByStyle(l10n, style);
          final List<String> lighting = AiPromptPools.lighting(l10n);
          final List<String> palettes = AiPromptPools.palettes(l10n);
          for (int scene = 0; scene < scenes.length; scene++) {
            for (int light = 0; light < lighting.length; light++) {
              for (int palette = 0; palette < palettes.length; palette++) {
                final _PromptIndicesRandom random = _PromptIndicesRandom(<int>[scene, light, palette]);
                final String prompt = AiPromptPools.randomPrompt(l10n, style, random);
                expect(random.isExhausted, isTrue);
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

class _PromptIndicesRandom implements Random {
  _PromptIndicesRandom(this._indices);

  final List<int> _indices;
  int _offset = 0;

  bool get isExhausted => _offset == _indices.length;

  @override
  int nextInt(int max) {
    if (max != 8 || _offset >= _indices.length) {
      throw StateError('Update the exhaustive matrix when a prompt pool changes size.');
    }
    return _indices[_offset++];
  }

  @override
  bool nextBool() => throw UnsupportedError('nextBool is not used by randomPrompt');

  @override
  double nextDouble() => throw UnsupportedError('nextDouble is not used by randomPrompt');
}
