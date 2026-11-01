import 'package:Prism/features/ai_wallpaper/domain/entities/ai_duo_composition.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Duo uses the canonical landscape target and trims both independent prompts', () {
    final duo = AiDuoComposition(foldedPrompt: '  sleepy cat  ', revealedPrompt: '  spaceship outside  ');
    expect(duo.foldedPrompt, 'sleepy cat');
    expect(duo.revealedPrompt, 'spaceship outside');
    expect(AiDuoComposition.targetSize, '2670x1878');
    expect(AiDuoComposition.format, 'duo-reveal');
    expect(() => AiDuoComposition(foldedPrompt: ' ', revealedPrompt: 'cat'), throwsArgumentError);
    expect(() => AiDuoComposition(foldedPrompt: 'cat', revealedPrompt: 'x' * 161), throwsArgumentError);
    expect(AiDuoComposition.isValidPrompt('x' * 160), isTrue);
  });

  test('Duo metadata survives restore, confirmation and resave without changing real dimensions or assets', () {
    final record = AiGenerationRecord.fromJson(<String, dynamic>{
      'id': 'duo-1',
      'userId': 'owner',
      'prompt': 'cat',
      'format': 'duo-reveal',
      'foldedPrompt': 'cat',
      'revealedPrompt': 'spaceship',
      'width': 2688,
      'height': 1888,
      'imageUrl': 'https://cdn/full.png',
      'watermarkedImageUrl': 'https://cdn/full-watermarked.png',
      'qualityTier': 'quality',
      'stylePreset': 'nature',
    });
    final restored = AiGenerationRecord.fromJson(
      record.copyWith(submittedWallId: 'wall', status: 'submitted').toJson(),
    );
    expect(restored.isDuoReveal, isTrue);
    expect(restored.foldedPrompt, 'cat');
    expect(restored.revealedPrompt, 'spaceship');
    expect(restored.width, 2688);
    expect(restored.height, 1888);
    expect(restored.displayUrl(isPremium: true), 'https://cdn/full.png');
    expect(restored.displayUrl(isPremium: false), 'https://cdn/full-watermarked.png');
    expect(restored.qualityTier.apiValue, 'quality');
    expect(isAiAspectRatioMismatch(generated: restored, targetSize: AiDuoComposition.targetSize), isFalse);
    expect(isAiAspectRatioMismatch(generated: restored, targetSize: '1080x1920'), isTrue);
    expect(AiGenerationRecord.fromJson(<String, dynamic>{}).isDuoReveal, isFalse);
  });
}
