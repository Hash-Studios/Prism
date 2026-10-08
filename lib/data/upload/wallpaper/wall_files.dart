import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/logger/logger.dart';

/// Where a submitted wall's two files live in the repo. The submission stores these so the creator can free the
/// upload slot by deleting the files while the wall is still in review.
class WallFileFields {
  const WallFileFields._();

  static const String wallpaperPath = 'wallpaper_path';
  static const String wallpaperSha = 'wallpaper_sha';
  static const String thumbPath = 'thumb_path';
  static const String thumbSha = 'thumb_sha';
}

/// Deletes the repo files of a pending wall. A file the doc has no path and sha for (older walls) is skipped, and a
/// failed delete is logged and does not stop the next one. Returns how many files were deleted.
Future<int> deleteWallFiles(Map<String, dynamic> wallData, {GitHubContentApi? github, String? repo}) async {
  final GitHubContentApi api = github ?? GitHubContentApi();
  final String targetRepo = repo ?? Env.normalize(Env.ghRepoWalls);
  int deleted = 0;
  for (final (String pathField, String shaField) in <(String, String)>[
    (WallFileFields.wallpaperPath, WallFileFields.wallpaperSha),
    (WallFileFields.thumbPath, WallFileFields.thumbSha),
  ]) {
    final Object? path = wallData[pathField];
    final Object? sha = wallData[shaField];
    if (path is! String || path.isEmpty || sha is! String || sha.isEmpty) continue;
    try {
      await api.deleteFile(repo: targetRepo, path: path, sha: sha, message: path);
      deleted++;
    } catch (error, stackTrace) {
      logger.w('Could not delete a file of a removed wall.', tag: 'Upload', error: error, stackTrace: stackTrace);
    }
  }
  return deleted;
}
