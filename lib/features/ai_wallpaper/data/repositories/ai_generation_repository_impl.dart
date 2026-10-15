import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

class AiGenerationApiException implements Exception {
  AiGenerationApiException({required this.message, required this.code, required this.statusCode});

  final String message;
  final String code;
  final int statusCode;

  @override
  String toString() => 'AiGenerationApiException(code: $code, statusCode: $statusCode, message: $message)';
}

typedef AiSubmissionMetadata = ({String title, String description, String category, List<String> tags});

@lazySingleton
class AiGenerationRepositoryImpl {
  static const String _apiBase = 'https://prismwalls.com/api/ai';

  AiGenerationRepositoryImpl()
    : _client = http.Client(),
      _auth = FirebaseAuth.instance,
      _requestTimeout = _defaultTimeout;

  @visibleForTesting
  AiGenerationRepositoryImpl.forTest({
    required http.Client client,
    required FirebaseAuth auth,
    Duration requestTimeout = _defaultTimeout,
  }) : _client = client,
       _auth = auth,
       _requestTimeout = requestTimeout;

  static const Duration _defaultTimeout = Duration(seconds: 60);

  final http.Client _client;
  final FirebaseAuth _auth;
  final Duration _requestTimeout;

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw AiGenerationApiException(
        message: 'Please sign in to generate wallpapers.',
        code: 'unauthorized',
        statusCode: 401,
      );
    }
    return user;
  }

  Future<AiGenerationRecord> generate({
    required String prompt,
    required AiStylePreset stylePreset,
    required AiQualityTier qualityTier,
    required String targetSize,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    int? seed,
    String? chargeTxId,
  }) async {
    final user = _requireUser();

    final payload = <String, dynamic>{
      'prompt': prompt,
      'stylePreset': stylePreset.apiValue,
      'qualityTier': qualityTier.apiValue,
      'targetSize': targetSize,
      if (seed != null) 'seed': seed,
      if (chargeTxId != null && chargeTxId.isNotEmpty) 'chargeTxId': chargeTxId,
    };
    final data = await _post('/generations', payload, retryOnTimeout: payload.containsKey('chargeTxId'));
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

  Future<AiGenerationRecord> generateVariation({
    required String generationId,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    String variationPrompt = '',
    double strength = 0.45,
    String? chargeTxId,
  }) async {
    final user = _requireUser();

    final AiGenerationRecord? original = await _fetchById(generationId);
    final payload = <String, dynamic>{
      'variationPrompt': variationPrompt,
      'strength': strength,
      if (chargeTxId != null && chargeTxId.isNotEmpty) 'chargeTxId': chargeTxId,
    };
    final data = await _post(
      '/generations/$generationId/variations',
      payload,
      retryOnTimeout: payload.containsKey('chargeTxId'),
    );
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

  Future<AiSubmissionMetadata> prefillSubmissionMetadata({
    required String generationId,
    required List<String> defaultTags,
  }) async {
    final data = await _post('/metadata/prefill', <String, dynamic>{'generationId': generationId});
    final Object? rawTags = data['tags'];
    return (
      title: parseString(data['title']).trim(),
      description: parseString(data['description']).trim(),
      category: parseString(data['category']).trim(),
      tags: rawTags is List
          ? rawTags
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : defaultTags,
    );
  }

  Future<void> saveHistoryRecord(AiGenerationRecord record) async {
    await firestoreClient.setDoc(
      FirebaseCollections.aiGenerations,
      record.id,
      record.toJson(),
      merge: true,
      sourceTag: 'ai.history.save',
    );
  }

  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async {
    try {
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
    } on FirestoreError catch (error) {
      if (error.code != 'failed-precondition') {
        rethrow;
      }
      final fallbackRows = await firestoreClient.query<AiGenerationRecord>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.aiGenerations,
          sourceTag: 'ai.history.fetch.missing_index_fallback',
          filters: <FirestoreFilter>[FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId)],
          dedupeWindowMs: 2000,
        ),
        (data, docId) => AiGenerationRecord.fromJson(data, fallbackId: docId),
      );
      fallbackRows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (limit <= 0 || fallbackRows.length <= limit) {
        return fallbackRows;
      }
      return fallbackRows.sublist(0, limit);
    }
  }

  Future<AiGenerationRecord?> _fetchById(String generationId) {
    return firestoreClient.getById<AiGenerationRecord>(
      FirebaseCollections.aiGenerations,
      generationId,
      (data, docId) => AiGenerationRecord.fromJson(data, fallbackId: docId),
      sourceTag: 'ai.history.fetch_by_id',
    );
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {bool retryOnTimeout = false}) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.trim().isEmpty) {
      throw AiGenerationApiException(message: 'Please sign in to continue.', code: 'unauthorized', statusCode: 401);
    }

    Future<http.Response> send() => _client
        .post(
          Uri.parse('$_apiBase$path'),
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);

    http.Response response;
    try {
      response = await send();
    } on TimeoutException {
      // The worker stores the finished image under the charge id, so a retry returns it instead of a second image.
      if (!retryOnTimeout) rethrow;
      response = await send();
    }

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
      seed: parseInt(data['seed']) ?? 0,
      width: parseInt(data['width']) ?? 1080,
      height: parseInt(data['height']) ?? 1920,
      imageUrl: imageUrl,
      watermarkedImageUrl: watermarkedImageUrl,
      chargeMode: chargeMode,
      coinsSpent: coinsSpent,
      status: 'success',
      parentGenerationId: parentGenerationId,
    );
  }
}
