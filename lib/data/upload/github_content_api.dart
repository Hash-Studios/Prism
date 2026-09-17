import 'package:cloud_functions/cloud_functions.dart' as cf;

class GitHubContent {
  const GitHubContent({required this.downloadUrl, required this.path, required this.sha});

  factory GitHubContent.fromData(Map<String, dynamic> data) {
    final Map<String, dynamic> content = (data['content'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return GitHubContent(
      downloadUrl: content['download_url'] as String?,
      path: content['path'] as String?,
      sha: content['sha'] as String?,
    );
  }

  final String? downloadUrl;
  final String? path;
  final String? sha;
}

class GitHubContentApi {
  static const String _region = 'asia-south1';

  cf.FirebaseFunctions get _functions => cf.FirebaseFunctions.instanceFor(region: _region);

  Future<GitHubContent> putFile({
    required String repo,
    required String path,
    required String contentBase64,
    required String message,
    String? sha,
  }) async {
    final result = await _functions.httpsCallable('githubPutFile').call(<String, dynamic>{
      'repo': repo,
      'path': path,
      'contentBase64': contentBase64,
      'message': message,
      if (sha != null) 'sha': sha,
    });
    return GitHubContent.fromData(Map<String, dynamic>.from(result.data as Map));
  }

  Future<void> deleteFile({
    required String repo,
    required String path,
    required String sha,
    required String message,
  }) async {
    await _functions.httpsCallable('githubDeleteFile').call(<String, dynamic>{
      'repo': repo,
      'path': path,
      'sha': sha,
      'message': message,
    });
  }
}
