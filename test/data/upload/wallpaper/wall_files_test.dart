import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/wallpaper/wall_files.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingGitHub extends GitHubContentApi {
  final List<({String repo, String path, String sha})> deleted = <({String repo, String path, String sha})>[];
  final Set<String> failPaths = <String>{};
  final List<UploadSourceKind?> sourceKinds = <UploadSourceKind?>[];
  final List<({String wallId, String originalObjectId, String assetRole})> assets = [];

  @override
  Future<void> deleteWallAsset({
    required String wallId,
    required String originalObjectId,
    required String assetRole,
  }) async {
    if (failPaths.contains(assetRole)) throw StateError('cleanup down');
    assets.add((wallId: wallId, originalObjectId: originalObjectId, assetRole: assetRole));
  }

  @override
  Future<void> deleteFile({
    required String repo,
    required String path,
    required String sha,
    required String message,
    UploadSourceKind? sourceKind,
  }) async {
    if (failPaths.contains(path)) throw StateError('github down');
    sourceKinds.add(sourceKind);
    deleted.add((repo: repo, path: path, sha: sha));
  }
}

void main() {
  const wall = <String, dynamic>{
    'wallpaper_path': 'u_1_a.png',
    'wallpaper_sha': 'sha-a',
    'thumb_path': 'thumb_u_1_a.png',
    'thumb_sha': 'sha-t',
  };

  test('protected wall cleanup uses only wall identity and attempts both assets on failure', () async {
    final github = _RecordingGitHub()..failPaths.add('wallpaper');
    final objectId = List<String>.filled(64, 'a').join();
    final count = await deleteWallFiles(
      <String, dynamic>{
        'id': 'wall',
        'originalProtected': true,
        'originalObjectId': objectId,
        'wallpaper_path': '',
        'wallpaper_sha': '',
        'thumb_path': '',
        'thumb_sha': '',
      },
      github: github,
      repo: 'org/walls',
    );
    expect(count, 1);
    expect(github.assets, [(wallId: 'wall', originalObjectId: objectId, assetRole: 'thumb')]);
    expect(github.deleted, isEmpty);
  });

  test('pending cleanup forwards independent source kinds, not mutable URLs', () async {
    final github = _RecordingGitHub();
    await deleteWallFiles(
      <String, dynamic>{
        ...wall,
        'wallpaper_source_kind': 'owned',
        'thumb_source_kind': 'github',
        'wallpaper_url': 'https://raw.githubusercontent.com/untrusted/path.jpg',
      },
      github: github,
      repo: 'org/walls',
    );
    expect(github.sourceKinds, <UploadSourceKind?>[UploadSourceKind.owned, UploadSourceKind.github]);
  });

  test('legacy empty originals and invalid selectors remain unspecified', () async {
    final github = _RecordingGitHub();
    await deleteWallFiles(
      <String, dynamic>{...wall, 'wallpaper_url': '', 'thumb_source_kind': 'invalid'},
      github: github,
      repo: 'org/walls',
    );
    expect(github.sourceKinds, <Object?>[null, null]);
  });

  test('deletes both files of a pending wall so the weekly slot comes back', () async {
    final github = _RecordingGitHub();

    final count = await deleteWallFiles(wall, github: github, repo: 'org/walls');

    expect(count, 2);
    expect(github.deleted.map((d) => (d.repo, d.path, d.sha)), <(String, String, String)>[
      ('org/walls', 'u_1_a.png', 'sha-a'),
      ('org/walls', 'thumb_u_1_a.png', 'sha-t'),
    ]);
  });

  test('a failed delete does not stop the next one and does not throw', () async {
    final github = _RecordingGitHub()..failPaths.add('u_1_a.png');

    final count = await deleteWallFiles(wall, github: github, repo: 'org/walls');

    expect(count, 1);
    expect(github.deleted.single.path, 'thumb_u_1_a.png');
  });

  test('walls saved before the file details were stored are skipped', () async {
    final github = _RecordingGitHub();

    final count = await deleteWallFiles(
      <String, dynamic>{'wallpaper_url': 'https://x/y.png'},
      github: github,
      repo: 'r',
    );

    expect(count, 0);
    expect(github.deleted, isEmpty);
  });
}
