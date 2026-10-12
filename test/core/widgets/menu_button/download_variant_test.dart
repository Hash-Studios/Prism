import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

DownloadVariant _variant(String key) => DownloadVariant(key: key, prepare: () async => '/cache/prism_tint/1_0.png');

void main() {
  group('identityOf', () {
    test('puts the key in the file name of the link', () {
      expect(_variant('tint-ff8800').identityOf('https://example.com/walls/sunset.jpg'), 'sunset_tint-ff8800.png');
    });

    test('is different for another key and for another wallpaper', () {
      final String base = _variant('tint-ff8800').identityOf('https://example.com/walls/sunset.jpg');

      expect(_variant('tint-0088ff').identityOf('https://example.com/walls/sunset.jpg'), isNot(base));
      expect(_variant('tint-ff8800').identityOf('https://example.com/walls/dawn.jpg'), isNot(base));
    });

    test('ignores the query string of the link', () {
      expect(
        _variant('tint-ff8800').identityOf('https://img.example.com/a/sunset.jpg?w=1080&q=80'),
        'sunset_tint-ff8800.png',
      );
    });

    test('keeps the whole name when the wallpaper name has a dot', () {
      final String identity = _variant('tint-ff8800').identityOf('https://example.com/my.wall.jpg');

      expect(downloadBaseName(identity), 'my.wall_tint-ff8800');
    });

    test('works for a local file path', () {
      expect(_variant('tint-ff8800').identityOf('/data/user/0/com.hash.prism/cache/wall.png'), 'wall_tint-ff8800.png');
    });

    test('gives the file name the native side saves the variation under', () {
      expect(
        downloadBaseName(_variant('tint-ff8800').identityOf('https://example.com/walls/sunset.jpg')),
        'sunset_tint-ff8800',
      );
    });
  });

  group('in the Downloads index', () {
    late DownloadedWallIndex index;

    setUp(() => index = DownloadedWallIndex(SettingsLocalDataSource(InMemoryLocalStore())));

    test('one variation is remembered without the original or another variation', () async {
      const String link = 'https://example.com/walls/sunset.jpg';
      await index.remember(link: _variant('tint-ff8800').identityOf(link), id: 'wall-1', source: WallpaperSource.prism);

      expect(index.has(_variant('tint-ff8800').identityOf(link)), isTrue);
      expect(index.has(_variant('tint-0088ff').identityOf(link)), isFalse);
      expect(index.has(link), isFalse);
    });

    test('the saved file opens the wallpaper it was made from', () async {
      const String link = 'https://example.com/walls/sunset.jpg';
      await index.remember(link: _variant('tint-ff8800').identityOf(link), id: 'wall-1', source: WallpaperSource.prism);

      expect(index.resolve('/storage/Pictures/Prism/Downloads/sunset_tint-ff8800.png'), (
        id: 'wall-1',
        source: WallpaperSource.prism,
      ));
      expect(index.resolve('/storage/Pictures/Prism/Downloads/sunset_tint-0088ff.png'), isNull);
    });
  });
}
