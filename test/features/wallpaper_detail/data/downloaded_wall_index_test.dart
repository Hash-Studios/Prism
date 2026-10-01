import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

void main() {
  late DownloadedWallIndex index;

  setUp(() => index = DownloadedWallIndex(SettingsLocalDataSource(InMemoryLocalStore())));

  test('resolves a remembered Prism download by its file name', () async {
    await index.remember(
      link: 'https://raw.githubusercontent.com/o/r/main/image_picker1529041162.png',
      id: 'abc123',
      source: WallpaperSource.prism,
    );

    expect(index.resolve('/Pictures/Prism/Downloads/image_picker1529041162.jpg'), (
      id: 'abc123',
      source: WallpaperSource.prism,
    ));
    expect(index.resolve('/Pictures/Prism/Downloads/image_picker1529041162 (1).jpg')?.id, 'abc123');
  });

  test('prefers an exact remembered name before interpreting a duplicate suffix', () async {
    await index.remember(link: 'https://example.com/image_picker.png', id: 'original', source: WallpaperSource.prism);
    await index.remember(
      link: 'https://example.com/image_picker%20(1).png',
      id: 'copy',
      source: WallpaperSource.pexels,
    );

    expect(index.resolve('/Pictures/image_picker (1).jpg'), (id: 'copy', source: WallpaperSource.pexels));
  });

  test('parses Wallhaven and Pexels ids from older downloads', () {
    expect(index.resolve('/d/wallhaven-mlp858 (1).jpg'), (id: 'mlp858', source: WallpaperSource.wallhaven));
    expect(index.resolve('/d/pexels-photo-1563016.jpeg.jpg'), (id: '1563016', source: WallpaperSource.pexels));
    expect(index.resolve('/d/pexels-photo-123abc.jpg'), isNull);
  });

  test('a persistence failure does not fail a completed download callback or erase old entries', () async {
    final FailingSetLocalStore store = FailingSetLocalStore();
    store.data['settings.downloaded_walls_v1'] = '{"existing":{"id":"old","source":"prism"}}';
    final DownloadedWallIndex failingIndex = DownloadedWallIndex(SettingsLocalDataSource(store));

    await expectLater(
      failingIndex.remember(link: 'https://example.com/new.png', id: 'new', source: WallpaperSource.prism),
      completes,
    );
    expect(failingIndex.resolve('/d/existing.jpg'), (id: 'old', source: WallpaperSource.prism));
  });

  test('returns null for unknown files', () {
    expect(index.resolve('/d/image_picker42.jpg'), isNull);
    expect(index.resolve('/d/default_1700000000.png'), isNull);
  });
}

class FailingSetLocalStore extends InMemoryLocalStore {
  @override
  Future<void> set(String key, Object? value) => Future<void>.error(StateError('set failed'));
}
