import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => EconomyConfig.resetForTest());
  tearDown(() => EconomyConfig.resetForTest());

  test('tierForModel maps known model families', () {
    expect(tierForModel('fal-ai/z-image/turbo'), AiQualityTier.fast);
    expect(tierForModel('openai/gpt-image-2.5/sunburst/text-to-image'), AiQualityTier.quality);
    expect(tierForModel('bytedance/seedream-4'), AiQualityTier.balanced);
  });

  test('tierForModel reads null and unknown models as balanced', () {
    expect(tierForModel(null), AiQualityTier.balanced);
    expect(tierForModel('some-other/model'), AiQualityTier.balanced);
  });

  test('remixTier keeps the original tier when the balance covers it', () {
    expect(
      remixTier(model: 'openai/gpt-image-2.5/sunburst/text-to-image', balance: 100, isPro: false),
      AiQualityTier.quality,
    );
  });

  test('remixTier steps down to balanced when the balance cannot pay for quality', () {
    expect(
      remixTier(model: 'openai/gpt-image-2.5/sunburst/text-to-image', balance: 80, isPro: false),
      AiQualityTier.balanced,
    );
  });

  test('remixTier steps down to fast when the balance cannot pay for balanced', () {
    expect(
      remixTier(model: 'openai/gpt-image-2.5/sunburst/text-to-image', balance: 20, isPro: false),
      AiQualityTier.fast,
    );
  });

  test('remixTier falls back to fast when the balance covers nothing', () {
    expect(
      remixTier(model: 'openai/gpt-image-2.5/sunburst/text-to-image', balance: 0, isPro: false),
      AiQualityTier.fast,
    );
  });

  test('remixTier charges Pro half price, rounded up', () {
    expect(
      remixTier(model: 'openai/gpt-image-2.5/sunburst/text-to-image', balance: 50, isPro: true),
      AiQualityTier.quality,
    );
    expect(
      remixTier(model: 'openai/gpt-image-2.5/sunburst/text-to-image', balance: 49, isPro: true),
      AiQualityTier.balanced,
    );
  });
}
