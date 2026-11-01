import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/upload_failure.dart';
import 'package:Prism/features/wallpaper_upload/biz/resubmission_seed.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';

class ResubmissionLimitException implements Exception {
  const ResubmissionLimitException();
}

class ResubmissionPreparation {
  const ResubmissionPreparation({
    required this.seed,
    this.original,
    this.unsupportedSource = false,
    this.temporaryOriginal = false,
  });
  final ResubmissionSeed seed;
  final File? original;
  final bool unsupportedSource;
  final bool temporaryOriginal;
}

class ResubmissionAdmission {
  const ResubmissionAdmission({required this.wallDocId, required this.logicalId, required this.attempt});
  final String wallDocId;
  final String logicalId;
  final int attempt;
}

class ResubmissionRepository {
  ResubmissionRepository(this._client);
  final FirestoreClient _client;

  Future<ResubmissionPreparation> prepare(String rejectedDocId, {required String uid, required String email}) async {
    final data = await _client.getById<Map<String, dynamic>>(
      FirebaseCollections.rejectedWalls,
      rejectedDocId,
      (data, _) => data,
      sourceTag: 'upload.resubmit.prepare',
    );
    if (data == null || (data['creatorUid'] is String ? data['creatorUid'] != uid : data['email'] != email)) {
      throw StateError('Rejected upload is not available to this owner.');
    }
    final seed = ResubmissionSeed(
      rejectedDocId: rejectedDocId,
      previousReason: data['rejectionReason'] is String ? data['rejectionReason'] as String : '',
      metadata: SubmissionMetadata(
        title: data['title'] is String ? data['title'] as String : '',
        description: data['desc'] is String ? data['desc'] as String : '',
        category: data['category'] is String && submissionCategories.contains(data['category'])
            ? data['category'] as String
            : defaultSubmissionCategory,
        tags: data['tags'] is List
            ? (data['tags'] as List).whereType<String>().take(maxSubmissionTags).toList()
            : const [],
      ),
    );
    final unsupported = data['isAiGenerated'] == true || data['origin'] == 'studio';
    if (unsupported) return ResubmissionPreparation(seed: seed, unsupportedSource: true);
    final rawUrl = data['wallpaper_url'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (url == null || url.scheme != 'https' || url.host.isEmpty) return ResubmissionPreparation(seed: seed);
    File? original;
    try {
      original = await _recover(url);
    } catch (_) {
      original = null;
    }
    return ResubmissionPreparation(seed: seed, original: original, temporaryOriginal: original != null);
  }

  Future<File?> _recover(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    final timeout = Timer(const Duration(seconds: 30), () => client.close(force: true));
    File? destination;
    try {
      final response = await (await client.getUrl(url)).close();
      if (response.statusCode != HttpStatus.ok || response.contentLength > maxUploadBytes) return null;
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        bytes.addAll(chunk);
        if (bytes.length > maxUploadBytes) return null;
      }
      if (bytes.isEmpty) return null;
      final codec = await instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
      final folder = await getTemporaryDirectory();
      destination = File('${folder.path}/prism-resubmit-${DateTime.now().microsecondsSinceEpoch}.jpg');
      await destination.writeAsBytes(bytes, flush: true);
      return destination;
    } catch (_) {
      if (destination != null && await destination.exists()) await destination.delete();
      return null;
    } finally {
      timeout.cancel();
      client.close(force: true);
    }
  }

  Future<ResubmissionAdmission> submit({
    required String operationId,
    required String rejectedDocId,
    required GitHubContent original,
    required GitHubContent thumbnail,
    required SubmissionMetadata metadata,
    required String resolution,
    required String size,
  }) async {
    Map<String, Object?> reference(GitHubContent file) => <String, Object?>{
      'path': file.path,
      'sha': file.sha,
      'sourceKind': (file.sourceKind ?? UploadSourceKind.github).name,
    };
    final HttpsCallableResult<Object?> result;
    try {
      result = await appFunctions.httpsCallable('submitWallResubmission').call<Object?>(<String, Object?>{
        'operationId': operationId,
        'sourceRejectedDocId': rejectedDocId,
        'original': reference(original),
        'thumbnail': reference(thumbnail),
        'metadata': <String, Object?>{
          'title': metadata.title,
          'desc': metadata.description,
          'tags': metadata.tags,
          'category': metadata.category,
        },
        'presentation': <String, Object?>{'resolution': resolution, 'size': size},
      });
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted' && error.message == 'resubmission-limit') {
        throw const ResubmissionLimitException();
      }
      rethrow;
    }
    final data = Map<String, dynamic>.from(result.data! as Map);
    return ResubmissionAdmission(
      wallDocId: data['wallDocId'] as String,
      logicalId: data['logicalId'] as String,
      attempt: (data['attempt'] as num).toInt(),
    );
  }
}
