import 'dart:convert';

import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/domain/repositories/ai_generation_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AiGenerationApiException implements Exception {
  AiGenerationApiException({required this.message, required this.code, required this.statusCode});

  final String message;
  final String code;
  final int statusCode;

  @override
  String toString() => 'AiGenerationApiException(code: $code, statusCode: $statusCode, message: $message)';
}

class AiGenerationRepositoryImpl implements AiGenerationRepository {
  AiGenerationRepositoryImpl({http.Client? client, FirebaseAuth? auth})
    : _client = client ?? http.Client(),
      _auth = auth ?? FirebaseAuth.instance;

  static const String _apiBase = 'https://prismwalls.com/api/ai';

  final http.Client _client;
  final FirebaseAuth _auth;

  @override
  Future<AiGenerationRecord> generate({
    required String prompt,
    required AiStylePreset stylePreset,
    required AiQualityTier qualityTier,
    required String targetSize,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    int? seed,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AiGenerationApiException(
        message: 'Please sign in to generate wallpapers.',
        code: 'unauthorized',
        statusCode: 401,
      );
    }

    final payload = <String, dynamic>{
      'prompt': prompt,
      'stylePreset': stylePreset.apiValue,
      'qualityTier': qualityTier.apiValue,
      'targetSize': targetSize,
      if (seed != null) 'seed': seed,
    };
    final data = await _post('/generations', payload);
    final record = _recordFromApiResponse(
      data: data,
      userId: user.uid,
      prompt: prompt,
      stylePreset: stylePreset,
      qualityTier: qualityTier,
      chargeMode: chargeMode,
      coinsSpent: coinsSpent,
    );
    try {
      await saveHistoryRecord(record);
    } catch (_) {
      // Keep generation success even if history persistence fails transiently.
    }
    return record;
  }

  @override
  Future<AiGenerationRecord> generateVariation({
    required String generationId,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    String variationPrompt = '',
    double strength = 0.45,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AiGenerationApiException(
        message: 'Please sign in to generate wallpapers.',
        code: 'unauthorized',
        statusCode: 401,
      );
    }

    final AiGenerationRecord? original = await _fetchById(generationId);
    final payload = <String, dynamic>{'variationPrompt': variationPrompt, 'strength': strength};
    final data = await _post('/generations/$generationId/variations', payload);
    final record = _recordFromApiResponse(
      data: data,
      userId: user.uid,
      prompt: variationPrompt.isEmpty ? (original?.prompt ?? '') : variationPrompt,
      stylePreset: original?.stylePreset ?? AiStylePreset.abstract,
      qualityTier: original?.qualityTier ?? AiQualityTier.balanced,
      chargeMode: chargeMode,
      coinsSpent: coinsSpent,
      parentGenerationId: generationId,
    );
    try {
      await saveHistoryRecord(record);
    } catch (_) {
      // Keep variation success even if history persistence fails transiently.
    }
    return record;
  }

  @override
  Future<Map<String, dynamic>> prefillSubmissionMetadata({required String generationId}) async {
    final data = await _post('/metadata/prefill', <String, dynamic>{'generationId': generationId});
    return data;
  }

  @override
  Future<void> saveHistoryRecord(AiGenerationRecord record) async {
    await firestoreClient.setDoc(
      FirebaseCollections.aiGenerations,
      record.id,
      record.toJson(),
      merge: true,
      sourceTag: 'ai.history.save',
    );
  }

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async {
    final rows = await firestoreClient.query<AiGenerationRecord>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.aiGenerations,
        sourceTag: 'ai.history.fetch',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId)],
        orderBy: <FirestoreOrderBy>[const FirestoreOrderBy(field: 'createdAt', descending: true)],
        limit: limit,
        dedupeWindowMs: 2000,
      ),
      (data, docId) => AiGenerationRecord.fromJson(data, fallbackId: docId),
    );
    return rows;
  }

  Future<AiGenerationRecord?> _fetchById(String generationId) async {
    return firestoreClient.getById<AiGenerationRecord>(
      FirebaseCollections.aiGenerations,
      generationId,
      (data, docId) => AiGenerationRecord.fromJson(data, fallbackId: docId),
      sourceTag: 'ai.history.fetch_by_id',
    );
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.trim().isEmpty) {
      throw AiGenerationApiException(message: 'Please sign in to continue.', code: 'unauthorized', statusCode: 401);
    }

    final response = await _client
        .post(
          Uri.parse('$_apiBase$path'),
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    Map<String, dynamic> payload = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      }
    } catch (_) {
      payload = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiGenerationApiException(
        message: (payload['message'] ?? 'Unable to process AI request').toString(),
        code: (payload['error'] ?? 'provider_error').toString(),
        statusCode: response.statusCode,
      );
    }
    return payload;
  }

  AiGenerationRecord _recordFromApiResponse({
    required Map<String, dynamic> data,
    required String userId,
    required String prompt,
    required AiStylePreset stylePreset,
    required AiQualityTier qualityTier,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    String? parentGenerationId,
  }) {
    int parseInt(dynamic raw, {int fallback = 0}) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    final imageUrls = data['imageUrls'] is Map<String, dynamic>
        ? data['imageUrls'] as Map<String, dynamic>
        : <String, dynamic>{};
    final imageUrl = (imageUrls['imageUrl'] ?? '').toString();
    final watermarkedImageUrl = (imageUrls['watermarkedImageUrl'] ?? imageUrl).toString();
    final generationId = (data['generationId'] ?? '').toString();
    if (generationId.trim().isEmpty || imageUrl.trim().isEmpty) {
      throw AiGenerationApiException(
        message: 'AI generation response was incomplete. Please retry.',
        code: 'provider_error',
        statusCode: 502,
      );
    }

    final responseQualityTier = AiQualityTier.fromApiValue((data['qualityTier'] ?? qualityTier.apiValue).toString());

    return AiGenerationRecord(
      id: generationId,
      userId: userId,
      createdAt: DateTime.now().toUtc(),
      prompt: prompt,
      stylePreset: stylePreset,
      qualityTier: responseQualityTier,
      provider: (data['provider'] ?? 'unknown').toString(),
      model: (data['model'] ?? '').toString(),
      seed: parseInt(data['seed']),
      width: parseInt(data['width'], fallback: 1080),
      height: parseInt(data['height'], fallback: 1920),
      imageUrl: imageUrl,
      watermarkedImageUrl: watermarkedImageUrl,
      chargeMode: chargeMode,
      coinsSpent: coinsSpent,
      status: 'success',
      parentGenerationId: parentGenerationId,
    );
  }
}
