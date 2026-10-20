import 'package:Prism/core/di/injection.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <Map<String, dynamic>>[];
  setUp(() async {
    calls.clear();
    final backend = CoinsTestBackend();
    await backend.install();
    backend.onCall = (name, parameters) async {
      expect(name, 'githubDeleteFile');
      calls.add(parameters);
      return <String, dynamic>{'ok': true};
    };
  });
  tearDown(getIt.reset);

  test('delete sends the selector only when authoritative upload details supplied one', () async {
    final api = GitHubContentApi();
    for (final kind in <UploadSourceKind?>[UploadSourceKind.owned, UploadSourceKind.github, null]) {
      await api.deleteFile(repo: 'walls', path: 'private.jpg', sha: 'sha', message: 'delete', sourceKind: kind);
    }
    expect(calls.map((call) => call['sourceKind']), <String?>['owned', 'github', null]);
    expect(calls.last.containsKey('sourceKind'), isFalse);
  });

  test('manifest cleanup sends only opaque wall identity, original generation and role', () async {
    await GitHubContentApi().deleteWallAsset(wallId: 'wall', originalGeneration: '17', assetRole: 'wallpaper');
    expect(calls.single, <String, dynamic>{'wallId': 'wall', 'originalGeneration': '17', 'assetRole': 'wallpaper'});
  });

  test('upload response retains authoritative source kind without URL inference', () {
    final content = GitHubContent.fromData(<String, dynamic>{
      'content': <String, dynamic>{'path': 'private.jpg', 'sha': 'sha', 'download_url': ''},
      'sourceKind': 'owned',
    });
    expect(content.sourceKind, UploadSourceKind.owned);
  });

  test('legacy and unknown source kinds stay unspecified, including empty originals', () {
    for (final kind in <Object?>[null, 'unexpected', 1]) {
      final content = GitHubContent.fromData(<String, dynamic>{
        'content': <String, dynamic>{'path': 'private.jpg', 'sha': 'sha', 'download_url': ''},
        if (kind != null) 'sourceKind': kind,
      });
      expect(content.sourceKind, isNull);
    }
  });
}
