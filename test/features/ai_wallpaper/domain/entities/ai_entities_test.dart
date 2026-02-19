import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ai style preset parsing is stable', () {
    expect(AiStylePreset.fromApiValue('anime'), AiStylePreset.anime);
    expect(AiStylePreset.fromApiValue('mesh_gradient'), AiStylePreset.meshGradient);
    expect(AiStylePreset.fromApiValue('unknown'), AiStylePreset.abstract);
  });

  test('ai quality tier parsing is stable', () {
    expect(AiQualityTier.fromApiValue('fast'), AiQualityTier.fast);
    expect(AiQualityTier.fromApiValue('quality'), AiQualityTier.quality);
    expect(AiQualityTier.fromApiValue('anything'), AiQualityTier.balanced);
  });

  test('ai charge mode parsing is stable', () {
    expect(AiChargeMode.fromValue('free_trial'), AiChargeMode.freeTrial);
    expect(AiChargeMode.fromValue('pro_included'), AiChargeMode.proIncluded);
    expect(AiChargeMode.fromValue('coin_spend'), AiChargeMode.coinSpend);
    expect(AiChargeMode.fromValue('invalid'), AiChargeMode.insufficient);
  });

  test('ai generation record maps from json', () {
    final record = AiGenerationRecord.fromJson(<String, dynamic>{
      'id': 'gen_123',
      'userId': 'u1',
      'createdAt': DateTime.utc(2026, 2, 18).toIso8601String(),
      'prompt': 'cyberpunk city',
      'stylePreset': 'cyberpunk',
      'qualityTier': 'balanced',
      'provider': 'fal',
      'model': 'fal-ai/flux/schnell',
      'seed': 42,
      'width': 1080,
      'height': 1920,
      'imageUrl': 'https://example.com/image.png',
      'watermarkedImageUrl': 'https://example.com/wm.png',
      'chargeMode': 'coin_spend',
      'coinsSpent': 20,
      'status': 'success',
    });

    expect(record.id, 'gen_123');
    expect(record.stylePreset, AiStylePreset.cyberpunk);
    expect(record.qualityTier, AiQualityTier.balanced);
    expect(record.chargeMode, AiChargeMode.coinSpend);
    expect(record.coinsSpent, 20);
  });
}
