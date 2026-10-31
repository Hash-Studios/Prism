import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
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
  static const int maxLocalHistoryRecords = 50;

  AiGenerationRepositoryImpl()
    : _client = http.Client(),
      _authOverride = null,
      _localStore = DurableJsonStore('ai_wallpaper'),
      _requestTimeout = _defaultTimeout;

  @visibleForTesting
  AiGenerationRepositoryImpl.forTest({
    required http.Client client,
    required FirebaseAuth auth,
    DurableJsonStore? localStore,
    Duration requestTimeout = _defaultTimeout,
  }) : _client = client,
       _authOverride = auth,
       _localStore = localStore ?? DurableJsonStore('ai_wallpaper'),
       _requestTimeout = requestTimeout;

  static const Duration _defaultTimeout = Duration(seconds: 60);

  final http.Client _client;
  final FirebaseAuth? _authOverride;
  final DurableJsonStore _localStore;
  final Duration _requestTimeout;
  final Map<String, int> _ownerGenerations = <String, int>{};
  final Map<String, Future<void>> _ownerWriteTails = <String, Future<void>>{};

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  int _generationFor(String userId) => _ownerGenerations[userId] ?? 0;

  bool _isCurrentGeneration(String userId, int generation) => _generationFor(userId) == generation;

  Future<void> _serializeOwnerWrite(String userId, int generation, Future<void> Function() operation) {
    final Future<void> previous = _ownerWriteTails[userId] ?? Future<void>.value();
    final Future<void> write = previous.then((_) async {
      if (_isCurrentGeneration(userId, generation)) await operation();
    });
    _ownerWriteTails[userId] = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }

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
    String? format,
    String? foldedPrompt,
    String? revealedPrompt,
    String? chargeTxId,
    String? remixOf,
  }) async {
    final user = _requireUser();
    final int ownerGeneration = _generationFor(user.uid);

    final payload = <String, dynamic>{
      'prompt': prompt,
      'stylePreset': stylePreset.apiValue,
      'qualityTier': qualityTier.apiValue,
      'targetSize': targetSize,
      if (format != null) 'format': format,
      if (foldedPrompt != null) 'foldedPrompt': foldedPrompt.trim(),
      if (revealedPrompt != null) 'revealedPrompt': revealedPrompt.trim(),
      if (seed != null) 'seed': seed,
      if (chargeTxId != null && chargeTxId.isNotEmpty) 'chargeTxId': chargeTxId,
      // The worker owns the one free trial per account; a repeat replays the first image.
      if (chargeMode == AiChargeMode.freeTrial && (chargeTxId == null || chargeTxId.isEmpty)) 'freeTrial': true,
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
      remixOf: remixOf,
    );
    try {
      await _saveHistoryRecord(record, ownerGeneration);
    } catch (_) {
      // Keep generation success even if history persistence fails transiently.
    }
    return record;
  }

  Future<AiGenerationRecord> generateVariation({
    required String generationId,
    AiGenerationRecord? originalRecord,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    String variationPrompt = '',
    double strength = 0.45,
    String? chargeTxId,
    String? remixOf,
  }) async {
    final user = _requireUser();
    final int ownerGeneration = _generationFor(user.uid);

    final AiGenerationRecord? original = originalRecord ?? await _fetchById(generationId);
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
      remixOf: remixOf,
    );
    try {
      await _saveHistoryRecord(record, ownerGeneration);
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

  Future<void> saveHistoryRecord(AiGenerationRecord record) =>
      _saveHistoryRecord(record, _generationFor(record.userId));

  Future<void> _saveHistoryRecord(AiGenerationRecord record, int generation) async {
    await _serializeOwnerWrite(record.userId, generation, () async {
      await _localStore.write(_historyKey(record.userId, record.id), _recordJson(record, pending: true));
      if (!_isCurrentGeneration(record.userId, generation)) return;
      await _trimLocalHistory(record.userId);
    });
    if (!_isCurrentGeneration(record.userId, generation)) return;
    await firestoreClient
        .setDoc(
          FirebaseCollections.aiGenerations,
          record.id,
          record.toJson(),
          merge: true,
          sourceTag: 'ai.history.save',
        )
        .timeout(_requestTimeout);
    await _writeLocalRecord(record, generation, pending: false);
  }

  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async {
    final int generation = _generationFor(userId);
    late final List<AiGenerationRecord> remote;
    try {
      remote = await _fetchRemoteHistory(userId: userId, limit: limit);
    } catch (_) {
      if (!_isCurrentGeneration(userId, generation)) return const <AiGenerationRecord>[];
      final List<AiGenerationRecord> local = await fetchLocalHistory(userId: userId, limit: limit);
      if (!_isCurrentGeneration(userId, generation)) return const <AiGenerationRecord>[];
      if (local.isNotEmpty) return local;
      rethrow;
    }
    if (!_isCurrentGeneration(userId, generation)) return const <AiGenerationRecord>[];
    try {
      await _serializeOwnerWrite(userId, generation, () async {
        for (final AiGenerationRecord record in remote) {
          if (!_isCurrentGeneration(userId, generation)) return;
          await _localStore.write(_historyKey(userId, record.id), _recordJson(record, pending: false));
        }
        if (_isCurrentGeneration(userId, generation)) await _trimLocalHistory(userId);
      });
    } on Object {}
    if (!_isCurrentGeneration(userId, generation)) return const <AiGenerationRecord>[];
    final List<AiGenerationRecord> pending = await _fetchPendingHistory(userId: userId, limit: limit);
    if (!_isCurrentGeneration(userId, generation)) return const <AiGenerationRecord>[];
    final Map<String, AiGenerationRecord> combined = <String, AiGenerationRecord>{
      for (final AiGenerationRecord record in pending) record.id: record,
      for (final AiGenerationRecord record in remote) record.id: record,
    };
    final List<AiGenerationRecord> result = combined.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result.take(limit).toList(growable: false);
  }

  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async {
    if (userId.trim().isEmpty || limit <= 0) return const <AiGenerationRecord>[];
    final String prefix = 'history/${Uri.encodeComponent(userId)}/';
    final Map<String, Map<String, Object?>> records = await _localStore.readAll();
    final List<AiGenerationRecord> result = <AiGenerationRecord>[];
    for (final MapEntry<String, Map<String, Object?>> entry in records.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      try {
        final AiGenerationRecord record = AiGenerationRecord.fromJson(entry.value);
        if (record.userId == userId && record.id.isNotEmpty) result.add(record);
      } on Object {
        continue;
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result.take(limit).toList(growable: false);
  }

  Future<List<AiGenerationRecord>> _fetchPendingHistory({required String userId, required int limit}) async {
    if (limit <= 0) return const <AiGenerationRecord>[];
    final String prefix = 'history/${Uri.encodeComponent(userId)}/';
    final Map<String, Map<String, Object?>> records = await _localStore.readAll();
    final List<AiGenerationRecord> result = <AiGenerationRecord>[];
    for (final MapEntry<String, Map<String, Object?>> entry in records.entries) {
      if (!entry.key.startsWith(prefix) || entry.value['_syncState'] != 'pending') continue;
      try {
        final AiGenerationRecord record = AiGenerationRecord.fromJson(entry.value);
        if (record.userId == userId && record.id.isNotEmpty) result.add(record);
      } on Object {
        continue;
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result.take(limit).toList(growable: false);
  }

  Future<void> _writeLocalRecord(AiGenerationRecord record, int generation, {required bool pending}) =>
      _serializeOwnerWrite(record.userId, generation, () async {
        if (!_isCurrentGeneration(record.userId, generation)) return;
        await _localStore.write(_historyKey(record.userId, record.id), _recordJson(record, pending: pending));
      });

  Future<String?> loadPrompt({required String userId}) async {
    if (userId.trim().isEmpty) return null;
    final Map<String, Object?>? record = await _localStore.read(_promptKey(userId));
    if (record == null || record['owner'] != userId || record['prompt'] is! String) return null;
    return record['prompt']! as String;
  }

  Future<void> savePrompt({required String userId, required String prompt}) async {
    if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
    final int generation = _generationFor(userId);
    await _serializeOwnerWrite(
      userId,
      generation,
      () => _localStore.write(_promptKey(userId), <String, Object?>{'owner': userId, 'prompt': prompt}),
    );
  }

  Future<void> clearForUser(String userId) async {
    if (userId.trim().isEmpty) return;
    final int generation = _generationFor(userId) + 1;
    _ownerGenerations[userId] = generation;
    await _serializeOwnerWrite(userId, generation, () async {
      final String historyPrefix = 'history/${Uri.encodeComponent(userId)}/';
      final Map<String, Map<String, Object?>> records = await _localStore.readAll();
      for (final String key in records.keys.where((key) => key.startsWith(historyPrefix))) {
        await _localStore.delete(key);
      }
      await _localStore.delete(_promptKey(userId));
    });
  }

  Future<void> _trimLocalHistory(String userId) async {
    final String prefix = 'history/${Uri.encodeComponent(userId)}/';
    final Map<String, Map<String, Object?>> records = await _localStore.readAll();
    final List<MapEntry<String, Map<String, Object?>>> owned = records.entries
        .where((entry) => entry.key.startsWith(prefix))
        .toList(growable: false);
    owned.sort((a, b) => (b.value['createdAt']?.toString() ?? '').compareTo(a.value['createdAt']?.toString() ?? ''));
    for (final entry in owned.skip(maxLocalHistoryRecords)) {
      await _localStore.delete(entry.key);
    }
  }

  static Map<String, Object?> _recordJson(AiGenerationRecord record, {required bool pending}) => <String, Object?>{
    ...record.toJson(),
    'createdAt': record.createdAt.toUtc().toIso8601String(),
    'submittedAt': record.submittedAt?.toUtc().toIso8601String(),
    '_syncState': pending ? 'pending' : 'synced',
  };

  static String _historyKey(String userId, String generationId) =>
      'history/${Uri.encodeComponent(userId)}/${Uri.encodeComponent(generationId)}';

  static String _promptKey(String userId) => 'prompt/${Uri.encodeComponent(userId)}';

  Future<List<AiGenerationRecord>> _fetchRemoteHistory({required String userId, int limit = 50}) async {
    try {
      final rows = await firestoreClient
          .query<AiGenerationRecord>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.aiGenerations,
              sourceTag: 'ai.history.fetch',
              filters: <FirestoreFilter>[
                FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId),
              ],
              orderBy: <FirestoreOrderBy>[const FirestoreOrderBy(field: 'createdAt', descending: true)],
              limit: limit,
              dedupeWindowMs: 2000,
            ),
            (data, docId) => AiGenerationRecord.fromJson(data, fallbackId: docId),
          )
          .timeout(_requestTimeout);
      return rows;
    } on FirestoreError catch (error) {
      if (error.code != 'failed-precondition') {
        rethrow;
      }
      final fallbackRows = await firestoreClient
          .query<AiGenerationRecord>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.aiGenerations,
              sourceTag: 'ai.history.fetch.missing_index_fallback',
              filters: <FirestoreFilter>[
                FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId),
              ],
              dedupeWindowMs: 2000,
            ),
            (data, docId) => AiGenerationRecord.fromJson(data, fallbackId: docId),
          )
          .timeout(_requestTimeout);
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

    Future<http.Response> send() => PerformanceProbe.measure(
      'http',
      'ai.generate$path',
      () => _client
          .post(
            Uri.parse('$_apiBase$path'),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout),
    );

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
    String? remixOf,
  }) {
    final imageUrls = data['imageUrls'] is Map<String, dynamic>
        ? data['imageUrls'] as Map<String, dynamic>
        : <String, dynamic>{};
    final imageUrl = imageUrls['imageUrl'];
    final watermarkedImageUrl = imageUrls['watermarkedImageUrl'] ?? imageUrl;
    final generationId = data['generationId'];
    if (generationId is! String ||
        generationId.trim().isEmpty ||
        imageUrl is! String ||
        imageUrl.trim().isEmpty ||
        watermarkedImageUrl is! String) {
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
      format: data['format']?.toString(),
      foldedPrompt: data['foldedPrompt']?.toString(),
      revealedPrompt: data['revealedPrompt']?.toString(),
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
      remixOf: remixOf,
    );
  }
}
