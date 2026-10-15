import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/wallpaper/wall_files.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingGitHub extends GitHubContentApi {
  final List<({String repo, String path, String sha})> deleted = <({String repo, String path, String sha})>[];
  final Set<String> failPaths = <String>{};

  @override
  Future<void> deleteFile({
    required String repo,
    required String path,
    required String sha,
    required String message,
  }) async {
    if (failPaths.contains(path)) throw StateError('github down');
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
