import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bundled-wallpapers-test-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('loads bundled starters as local originals resolvable without network', () async {
    final items = await BundledWallpapers.load(directory: directory);

    expect(items, isNotEmpty);
    expect(items.map((item) => item.id).toSet(), hasLength(items.length));
    for (final item in items) {
      expect(item.fullUrl, isNotEmpty);
      expect(item.fullUrl, isNot(startsWith('http')));
      expect(item.thumbnailUrl, item.fullUrl);
      final File resolved = await OfflineAssetStore().resolve(item.fullUrl, allowNetwork: false);
      expect(await resolved.exists(), isTrue);
      expect(await resolved.length(), greaterThan(0));
    }
  });
}
