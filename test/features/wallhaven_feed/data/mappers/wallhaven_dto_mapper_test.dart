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

    test('falls back to large when original is empty', () {
      const dto = WallhavenWallpaperDto(
        id: 'ab12cd',
        path: fullUrl,
        thumbs: WallhavenThumbsDto(large: 'large.jpg', original: '', small: 'small.jpg'),
      );

      expect(dto.toDomain().core.thumbnailUrl, 'large.jpg');
    });

    test('falls back to large when original is whitespace', () {
      const dto = WallhavenWallpaperDto(
        id: 'ab12cd',
        path: fullUrl,
        thumbs: WallhavenThumbsDto(large: 'large.jpg', original: '   ', small: 'small.jpg'),
      );

      expect(dto.toDomain().core.thumbnailUrl, 'large.jpg');
    });

    test('skips empty fallback URLs and uses full URL when all are empty', () {
      const cases = <(WallhavenThumbsDto, String)>[
        (WallhavenThumbsDto(original: '', large: '', small: 'small.jpg'), 'small.jpg'),
        (WallhavenThumbsDto(original: '', large: 'large.jpg', small: ''), 'large.jpg'),
        (WallhavenThumbsDto(original: '', large: '', small: ''), fullUrl),
      ];

      for (final (thumbs, expected) in cases) {
        final dto = WallhavenWallpaperDto(id: 'ab12cd', path: fullUrl, thumbs: thumbs);
        expect(dto.toDomain().core.thumbnailUrl, expected);
      }
    });

    test('falls back to the full url when thumbs are missing', () {
      const dto = WallhavenWallpaperDto(id: 'ab12cd', path: fullUrl);

      expect(dto.toDomain().core.thumbnailUrl, fullUrl);
    });
  });
}
