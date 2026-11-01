import 'package:Prism/data/upload/github_content_api.dart';

class UploadSession {
  const UploadSession({
    required this.operationId,
    required this.logicalId,
    this.rejectedDocId = '',
    this.previousReason = '',
    this.fileName,
    this.original,
    this.thumbnail,
    this.submissionAttempted = false,
  });

  final String operationId;
  final String logicalId;
  final String rejectedDocId;
  final String previousReason;
  final String? fileName;
  final GitHubContent? original;
  final GitHubContent? thumbnail;
  final bool submissionAttempted;

  Map<String, Object?> toJson() => <String, Object?>{
    'operationId': operationId,
    'logicalId': logicalId,
    'rejectedDocId': rejectedDocId,
    'previousReason': previousReason,
    'fileName': fileName,
    'submissionAttempted': submissionAttempted,
    'original': _fileJson(original),
    'thumbnail': _fileJson(thumbnail),
  };

  static UploadSession? fromJson(Object? raw) {
    if (raw is! Map || raw['operationId'] is! String || raw['logicalId'] is! String) return null;
    return UploadSession(
      operationId: raw['operationId'] as String,
      logicalId: raw['logicalId'] as String,
      rejectedDocId: raw['rejectedDocId'] is String ? raw['rejectedDocId'] as String : '',
      previousReason: raw['previousReason'] is String ? raw['previousReason'] as String : '',
      fileName: raw['fileName'] as String?,
      original: _fileFrom(raw['original']),
      thumbnail: _fileFrom(raw['thumbnail']),
      submissionAttempted: raw['submissionAttempted'] == true,
    );
  }

  static Map<String, Object?>? _fileJson(GitHubContent? file) => file == null
      ? null
      : <String, Object?>{
          'url': file.downloadUrl,
          'path': file.path,
          'sha': file.sha,
          'sourceKind': file.sourceKind?.name,
        };

  static GitHubContent? _fileFrom(Object? raw) => raw is Map && raw['path'] is String && raw['sha'] is String
      ? GitHubContent(
          downloadUrl: raw['url'] as String?,
          path: raw['path'] as String,
          sha: raw['sha'] as String,
          sourceKind: UploadSourceKind.fromData(raw['sourceKind']),
        )
      : null;
}
