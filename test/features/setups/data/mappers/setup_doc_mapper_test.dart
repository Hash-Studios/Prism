import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/setups/data/mappers/setup_doc_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps stored Wallhaven crop thumbnails to their uncropped URL', () {
    final setup = const SetupDocDto(
      id: 'setup-id',
      wallpaperProvider: 'wallhaven',
      wallpaperThumb: 'https://th.wallhaven.cc/small/21/wall.jpg',
    ).toSetupEntity('setup-doc-id');

    expect(setup.source, WallpaperSource.wallhaven);
    expect(setup.wallpaperThumb, 'https://th.wallhaven.cc/orig/21/wall.jpg');
  });

  test('leaves non-Wallhaven thumbnail URLs untouched', () {
    final setup = const SetupDocDto(
      id: 'setup-id',
      wallpaperProvider: 'pexels',
      wallpaperThumb: 'https://images.pexels.com/photos/1/tiny.jpg',
    ).toSetupEntity('setup-doc-id');

    expect(setup.wallpaperThumb, 'https://images.pexels.com/photos/1/tiny.jpg');
  });
}
