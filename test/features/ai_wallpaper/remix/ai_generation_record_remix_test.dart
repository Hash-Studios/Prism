import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:flutter_test/flutter_test.dart';

AiGenerationRecord _record({String? remixOf}) => AiGenerationRecord(
  id: 'generation-1',
  userId: 'user-1',
  createdAt: DateTime.utc(2026),
  prompt: 'neon koi pond at dusk',
  stylePreset: AiStylePreset.watercolor,
  qualityTier: AiQualityTier.fast,
  provider: 'fal',
  model: 'fal-ai/z-image/turbo',
  seed: 7,
  width: 1080,
  height: 1920,
  imageUrl: 'https://example.com/a.png',
  watermarkedImageUrl: 'https://example.com/w.png',
  chargeMode: AiChargeMode.coinSpend,
  coinsSpent: 10,
  status: 'success',
  remixOf: remixOf,
);

void main() {
  test('challenge context survives history and submission without changing remix linkage', () {
    final original = _record(remixOf: 'orig_1').copyWith(challengeId: '2026-10-26', challengeTheme: 'Quiet oceans');
    final restored = AiGenerationRecord.fromJson(
      original.toJson(),
    ).copyWith(status: 'submitted', submittedWallId: 'wall');
    expect(restored.challengeId, '2026-10-26');
    expect(restored.challengeTheme, 'Quiet oceans');
    expect(restored.remixOf, 'orig_1');
    expect(_record().challengeId, isNull);
  });

  test('toJson and fromJson keep remixOf', () {
    final AiGenerationRecord record = _record(remixOf: 'orig_1');

    final AiGenerationRecord decoded = AiGenerationRecord.fromJson(record.toJson());

    expect(record.toJson()['remixOf'], 'orig_1');
    expect(decoded.remixOf, 'orig_1');
  });

  test('copyWith sets remixOf', () {
    final AiGenerationRecord linked = _record().copyWith(remixOf: 'orig_1');

    expect(linked.remixOf, 'orig_1');
    expect(_record(remixOf: 'orig_1').copyWith(status: 'submitted').remixOf, 'orig_1');
  });

  test('a missing or blank remixOf reads as null', () {
    final Map<String, dynamic> json = _record().toJson()..remove('remixOf');
    expect(AiGenerationRecord.fromJson(json).remixOf, isNull);

    expect(AiGenerationRecord.fromJson(_record().toJson()..['remixOf'] = '  ').remixOf, isNull);
  });
}
