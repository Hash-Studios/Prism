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

  test('has() is true for a remembered link, whatever the extension, and false for others', () async {
    await index.remember(link: 'https://example.com/a/image_picker1.png', id: 'w1', source: WallpaperSource.prism);

    expect(index.has('https://example.com/a/image_picker1.png'), isTrue);
    expect(index.has('https://example.com/b/image_picker1.jpg'), isTrue);
    expect(index.has('https://example.com/a/image_picker2.png'), isFalse);
  });

  test('clear() forgets every entry', () async {
    await index.remember(link: 'https://example.com/one.png', id: 'w1', source: WallpaperSource.prism);
    await index.remember(link: 'https://example.com/two.png', id: 'w2', source: WallpaperSource.prism);

    await index.clear();

    expect(index.has('https://example.com/one.png'), isFalse);
    expect(index.resolve('/d/two.jpg'), isNull);
  });

  test('forget() drops the entry of a deleted file', () async {
    await index.remember(link: 'https://example.com/one.png', id: 'w1', source: WallpaperSource.prism);
    await index.remember(link: 'https://example.com/two.png', id: 'w2', source: WallpaperSource.prism);

    await index.forget(<String>['/d/one.jpg'], remainingPaths: <String>['/d/two.jpg']);

    expect(index.has('https://example.com/one.png'), isFalse);
    expect(index.has('https://example.com/two.png'), isTrue);
  });

  test('forget() keeps the entry while a copy of the file is left', () async {
    await index.remember(link: 'https://example.com/one.png', id: 'w1', source: WallpaperSource.prism);

    await index.forget(<String>['/d/one.jpg'], remainingPaths: <String>['/d/one (1).jpg']);
    expect(index.resolve('/d/one (1).jpg')?.id, 'w1');

    await index.forget(<String>['/d/one (1).jpg'], remainingPaths: const <String>[]);
    expect(index.has('https://example.com/one.png'), isFalse);
  });

  test('a copy of another wall with the same file name opens its own wall, not the first one', () async {
    await index.remember(link: 'https://example.com/shared.png', id: 'first', source: WallpaperSource.prism);
    await index.remember(link: 'https://example.com/shared%20(1).png', id: 'second', source: WallpaperSource.prism);

    expect(index.resolve('/d/shared (1).jpg')?.id, 'second');
    expect(index.resolve('/d/shared.jpg')?.id, 'first');
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
