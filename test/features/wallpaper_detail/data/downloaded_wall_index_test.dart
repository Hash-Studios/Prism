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

  test('parses Wallhaven and Pexels ids from older downloads', () {
    expect(index.resolve('/d/wallhaven-mlp858 (1).jpg'), (id: 'mlp858', source: WallpaperSource.wallhaven));
    expect(index.resolve('/d/pexels-photo-1563016.jpeg.jpg'), (id: '1563016', source: WallpaperSource.pexels));
  });

  test('returns null for unknown files', () {
    expect(index.resolve('/d/image_picker42.jpg'), isNull);
    expect(index.resolve('/d/default_1700000000.png'), isNull);
  });
}
