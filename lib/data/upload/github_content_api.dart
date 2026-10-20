import 'package:Prism/core/constants/app_functions.dart';

enum UploadSourceKind {
  owned,
  github;

  static UploadSourceKind? fromData(Object? value) => switch (value) {
    'owned' => owned,
    'github' => github,
    _ => null,
  };
}

class GitHubContent {
  const GitHubContent({required this.downloadUrl, required this.path, required this.sha, this.sourceKind});

  factory GitHubContent.fromData(Map<String, dynamic> data) {
    final Map<String, dynamic> content = (data['content'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return GitHubContent(
      downloadUrl: content['download_url'] as String?,
      path: content['path'] as String?,
      sha: content['sha'] as String?,
      sourceKind: UploadSourceKind.fromData(data['sourceKind']),
    );
  }

  final String? downloadUrl;
  final String? path;
  final String? sha;
  final UploadSourceKind? sourceKind;
}

class GitHubContentApi {
  Future<void> deleteWallAsset({
    required String wallId,
    required String originalObjectId,
    required String assetRole,
  }) async {
    await appFunctions.httpsCallable('githubDeleteFile').call(<String, dynamic>{
      'wallId': wallId,
      'originalObjectId': originalObjectId,
      'assetRole': assetRole,
    });
  }

  Future<GitHubContent> putFile({
    required String repo,
    required String path,
    required String contentBase64,
    required String message,
    String? sha,
    String? purpose,
  }) async {
    final result = await appFunctions.httpsCallable('githubPutFile').call(<String, dynamic>{
      'repo': repo,
      'path': path,
      'contentBase64': contentBase64,
      'message': message,
      if (sha != null) 'sha': sha,
      if (purpose != null) 'purpose': purpose,
    });
    return GitHubContent.fromData(Map<String, dynamic>.from(result.data as Map));
  }

  Future<void> deleteFile({
    required String repo,
    required String path,
    required String sha,
    required String message,
    UploadSourceKind? sourceKind,
  }) async {
    await appFunctions.httpsCallable('githubDeleteFile').call(<String, dynamic>{
      'repo': repo,
      'path': path,
      'sha': sha,
      'message': message,
      if (sourceKind != null) 'sourceKind': sourceKind.name,
    });
  }
}
