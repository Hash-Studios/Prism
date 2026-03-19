import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.errorCode,
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
  final String? errorCode;

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
      'errorCode': errorCode,
    };
  }

  factory AiGenerationRecord.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    int parseInt(dynamic raw, {int fallback = 0}) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    DateTime parseDate(dynamic raw) {
      if (raw is DateTime) return raw.toUtc();
      if (raw is Timestamp) return raw.toDate().toUtc();
      return DateTime.tryParse(raw?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc();
    }

    return AiGenerationRecord(
      id: (json['id'] ?? fallbackId ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      createdAt: parseDate(json['createdAt']),
      prompt: (json['prompt'] ?? '').toString(),
      stylePreset: AiStylePreset.fromApiValue((json['stylePreset'] ?? 'abstract').toString()),
      qualityTier: AiQualityTier.fromApiValue((json['qualityTier'] ?? 'balanced').toString()),
      provider: (json['provider'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      seed: parseInt(json['seed']),
      width: parseInt(json['width']),
      height: parseInt(json['height']),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      watermarkedImageUrl: (json['watermarkedImageUrl'] ?? json['imageUrl'] ?? '').toString(),
      chargeMode: AiChargeMode.fromValue(json['chargeMode']?.toString()),
      coinsSpent: parseInt(json['coinsSpent']),
      status: (json['status'] ?? 'success').toString(),
      parentGenerationId: json['parentGenerationId']?.toString(),
      submittedWallId: json['submittedWallId']?.toString(),
      submittedAt: json['submittedAt'] == null ? null : parseDate(json['submittedAt']),
      errorCode: json['errorCode']?.toString(),
    );
  }

  AiGenerationRecord copyWith({
    AiChargeMode? chargeMode,
    int? coinsSpent,
    String? submittedWallId,
    DateTime? submittedAt,
    String? status,
    String? errorCode,
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
      errorCode: errorCode ?? this.errorCode,
    );
  }
}
