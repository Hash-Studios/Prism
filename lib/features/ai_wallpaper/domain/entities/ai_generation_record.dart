import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';

class AiGenerationRecord {
  const AiGenerationRecord({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.prompt,
    required this.stylePreset,
    required this.qualityTier,
    required this.provider,
    required this.model,
    required this.seed,
    required this.width,
    required this.height,
    required this.imageUrl,
    required this.watermarkedImageUrl,
    required this.chargeMode,
    required this.coinsSpent,
    required this.status,
    this.parentGenerationId,
    this.submittedWallId,
    this.submittedAt,
  });

  final String id;
  final String userId;
  final DateTime createdAt;
  final String prompt;
  final AiStylePreset stylePreset;
  final AiQualityTier qualityTier;
  final String provider;
  final String model;
  final int seed;
  final int width;
  final int height;
  final String imageUrl;
  final String watermarkedImageUrl;
  final AiChargeMode chargeMode;
  final int coinsSpent;
  final String status;
  final String? parentGenerationId;
  final String? submittedWallId;
  final DateTime? submittedAt;

  String displayUrl({required bool isPremium}) => isPremium ? imageUrl : watermarkedImageUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'createdAt': createdAt.toUtc(),
      'prompt': prompt,
      'stylePreset': stylePreset.apiValue,
      'qualityTier': qualityTier.apiValue,
      'provider': provider,
      'model': model,
      'seed': seed,
      'width': width,
      'height': height,
      'imageUrl': imageUrl,
      'watermarkedImageUrl': watermarkedImageUrl,
      'chargeMode': chargeMode.value,
      'coinsSpent': coinsSpent,
      'status': status,
      'parentGenerationId': parentGenerationId,
      'submittedWallId': submittedWallId,
      'submittedAt': submittedAt?.toUtc(),
    };
  }

  factory AiGenerationRecord.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    DateTime parseDate(Object? raw) => parseDateTime(raw)?.toUtc() ?? DateTime.now().toUtc();

    return AiGenerationRecord(
      id: parseString(json['id'] ?? fallbackId),
      userId: parseString(json['userId']),
      createdAt: parseDate(json['createdAt']),
      prompt: parseString(json['prompt']),
      stylePreset: AiStylePreset.fromApiValue(parseString(json['stylePreset'], fallback: 'abstract')),
      qualityTier: AiQualityTier.fromApiValue(parseString(json['qualityTier'], fallback: 'balanced')),
      provider: parseString(json['provider']),
      model: parseString(json['model']),
      seed: parseInt(json['seed']) ?? 0,
      width: parseInt(json['width']) ?? 0,
      height: parseInt(json['height']) ?? 0,
      imageUrl: parseString(json['imageUrl']),
      watermarkedImageUrl: parseString(json['watermarkedImageUrl'] ?? json['imageUrl']),
      chargeMode: AiChargeMode.fromValue(json['chargeMode']?.toString()),
      coinsSpent: parseInt(json['coinsSpent']) ?? 0,
      status: parseString(json['status'], fallback: 'success'),
      parentGenerationId: json['parentGenerationId']?.toString(),
      submittedWallId: json['submittedWallId']?.toString(),
      submittedAt: json['submittedAt'] == null ? null : parseDate(json['submittedAt']),
    );
  }

  AiGenerationRecord copyWith({
    AiChargeMode? chargeMode,
    int? coinsSpent,
    String? submittedWallId,
    DateTime? submittedAt,
    String? status,
  }) {
    return AiGenerationRecord(
      id: id,
      userId: userId,
      createdAt: createdAt,
      prompt: prompt,
      stylePreset: stylePreset,
      qualityTier: qualityTier,
      provider: provider,
      model: model,
      seed: seed,
      width: width,
      height: height,
      imageUrl: imageUrl,
      watermarkedImageUrl: watermarkedImageUrl,
      chargeMode: chargeMode ?? this.chargeMode,
      coinsSpent: coinsSpent ?? this.coinsSpent,
      status: status ?? this.status,
      parentGenerationId: parentGenerationId,
      submittedWallId: submittedWallId ?? this.submittedWallId,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}
