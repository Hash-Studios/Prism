import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/logger/logger.dart';

/// Where a submitted wall's two files live in the repo. The submission stores these so the creator can free the
/// upload slot by deleting the files while the wall is still in review.
class WallFileFields {
  const WallFileFields._();

  static const String wallpaperPath = 'wallpaper_path';
  static const String wallpaperSha = 'wallpaper_sha';
  static const String wallpaperSourceKind = 'wallpaper_source_kind';
  static const String thumbPath = 'thumb_path';
  static const String thumbSha = 'thumb_sha';
  static const String thumbSourceKind = 'thumb_source_kind';
}

/// Deletes the repo files of a pending wall. A file the doc has no path and sha for (older walls) is skipped, and a
/// failed delete is logged and does not stop the next one. Returns how many files were deleted.
Future<int> deleteWallFiles(
  Map<String, dynamic> wallData, {
  GitHubContentApi? github,
  String? repo,
  bool throwOnFailure = false,
}) async {
  final GitHubContentApi api = github ?? GitHubContentApi();
  final String targetRepo = repo ?? Env.normalize(Env.ghRepoWalls);
  int deleted = 0;
  bool failed = false;
  if (wallData['originalProtected'] == true) {
    final Object? wallId = wallData['id'];
    final Object? objectId = wallData['originalObjectId'];
    if (wallId is! String || wallId.isEmpty || objectId is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(objectId)) {
      throw StateError('Protected wall cleanup requires its original identity.');
    }
    for (final role in <String>['wallpaper', 'thumb']) {
      try {
        await api.deleteWallAsset(wallId: wallId, originalObjectId: objectId, assetRole: role);
        deleted++;
      } catch (error, stackTrace) {
        failed = true;
        logger.w('Could not delete a file of a removed wall.', tag: 'Upload', error: error, stackTrace: stackTrace);
      }
    }
    if (failed && throwOnFailure) throw StateError('Some wallpaper files could not be deleted.');
    return deleted;
  }
  for (final (String pathField, String shaField, String kindField) in <(String, String, String)>[
    (WallFileFields.wallpaperPath, WallFileFields.wallpaperSha, WallFileFields.wallpaperSourceKind),
    (WallFileFields.thumbPath, WallFileFields.thumbSha, WallFileFields.thumbSourceKind),
  ]) {
    final Object? path = wallData[pathField];
    final Object? sha = wallData[shaField];
    if (path is! String || path.isEmpty || sha is! String || sha.isEmpty) continue;
    try {
      await api.deleteFile(
        repo: targetRepo,
        path: path,
        sha: sha,
        message: path,
        sourceKind: UploadSourceKind.fromData(wallData[kindField]),
      );
      deleted++;
    } catch (error, stackTrace) {
      failed = true;
      logger.w('Could not delete a file of a removed wall.', tag: 'Upload', error: error, stackTrace: stackTrace);
    }
  }
  if (failed && throwOnFailure) throw StateError('Some wallpaper files could not be deleted.');
  return deleted;
}
