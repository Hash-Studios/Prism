import 'package:Prism/features/wallhaven_feed/data/dtos/wallhaven_dtos.dart';
import 'package:Prism/features/wallhaven_feed/data/mappers/wallhaven_dto_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String fullUrl = 'https://w.wallhaven.cc/full/ab/wallhaven-ab12cd.jpg';

  group('WallhavenWallpaperDto.toDomain thumbnailUrl', () {
    test('prefers original to keep the real aspect ratio', () {
      const dto = WallhavenWallpaperDto(
        id: 'ab12cd',
        path: fullUrl,
        thumbs: WallhavenThumbsDto(large: 'large.jpg', original: 'original.jpg', small: 'small.jpg'),
      );

      expect(dto.toDomain().core.thumbnailUrl, 'original.jpg');
    });

    test('falls back to large when original is missing', () {
      const dto = WallhavenWallpaperDto(
        id: 'ab12cd',
        path: fullUrl,
        thumbs: WallhavenThumbsDto(large: 'large.jpg', small: 'small.jpg'),
      );

      expect(dto.toDomain().core.thumbnailUrl, 'large.jpg');
    });

    test('falls back to the full url when thumbs are missing', () {
      const dto = WallhavenWallpaperDto(id: 'ab12cd', path: fullUrl);

      expect(dto.toDomain().core.thumbnailUrl, fullUrl);
    });
  });
}
