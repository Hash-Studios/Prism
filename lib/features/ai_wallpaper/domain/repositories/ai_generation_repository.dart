import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';

abstract class AiGenerationRepository {
  Future<AiGenerationRecord> generate({
    required String prompt,
    required AiStylePreset stylePreset,
    required AiQualityTier qualityTier,
    required String targetSize,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    int? seed,
  });

  Future<AiGenerationRecord> generateVariation({
    required String generationId,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    String variationPrompt = '',
    double strength = 0.45,
  });

  Future<Map<String, dynamic>> prefillSubmissionMetadata({required String generationId});

  Future<void> saveHistoryRecord(AiGenerationRecord record);

  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50});
}
