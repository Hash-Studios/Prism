import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/data/dtos/pexels_dtos.dart';
import 'package:Prism/features/pexels_feed/data/mappers/pexels_dto_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

const String _tiny =
    'https://images.pexels.com/photos/1563016/pexels-photo-1563016.jpeg?auto=compress&cs=tinysrgb&fit=crop&h=200&w=280';
const String _uncropped =
    'https://images.pexels.com/photos/1563016/pexels-photo-1563016.jpeg?auto=compress&cs=tinysrgb&fit=max&h=200&w=280';

void main() {
  test('normalizes a cached Pexels tiny crop URL', () {
    const WallpaperCore core = WallpaperCore(
      id: '1563016',
      source: WallpaperSource.pexels,
      fullUrl: 'https://images.pexels.com/photos/1563016/pexels-photo-1563016.jpeg',
      thumbnailUrl: _tiny,
    );

    expect(core.thumbnailUrl, _uncropped);
  });

  test('does not rewrite Pexels resize URLs without both crop dimensions', () {
    const String medium =
        'https://images.pexels.com/photos/1563016/pexels-photo-1563016.jpeg?auto=compress&cs=tinysrgb&fit=crop&h=350';

    expect(
      const WallpaperCore(
        id: '1563016',
        source: WallpaperSource.pexels,
        fullUrl: 'full',
        thumbnailUrl: medium,
      ).thumbnailUrl,
      medium,
    );
  });

  test('normalizes percent-encoded Pexels crop parameter and preserves other params', () {
    const String encodedFit =
        'https://images.pexels.com/photos/1563016/pexels-photo-1563016.jpeg?auto=compress&fit=cr%6Fp&h=200&w=280&token=a%2Fb';
    final Uri normalized = Uri.parse(
      const WallpaperCore(
        id: '1563016',
        source: WallpaperSource.pexels,
        fullUrl: 'full',
        thumbnailUrl: encodedFit,
      ).thumbnailUrl,
    );

    expect(normalized.queryParameters['fit'], 'max');
    expect(normalized.queryParameters['token'], 'a/b');
    expect(normalized.queryParameters['auto'], 'compress');
  });

  test('malformed Pexels query encoding does not make thumbnail access throw', () {
    const String malformed = 'https://images.pexels.com/photos/1563016/pexels-photo-1563016.jpeg?fit=crop&h=%FF&w=280';

    expect(
      const WallpaperCore(
        id: '1563016',
        source: WallpaperSource.pexels,
        fullUrl: 'full',
        thumbnailUrl: malformed,
      ).thumbnailUrl,
      malformed,
    );
  });

  test('does not rewrite crop URLs from other hosts', () {
    const String other = 'https://example.com/photo.jpeg?fit=crop&h=200&w=280';

    expect(
      const WallpaperCore(id: '1', source: WallpaperSource.pexels, fullUrl: 'full', thumbnailUrl: other).thumbnailUrl,
      other,
    );
  });

  test('normalizes a tiny-only Pexels API response', () {
    final PexelsWallpaper wallpaper = const PexelsPhotoDto(id: 1563016, src: PexelsSrcDto(tiny: _tiny)).toDomain();

    expect(wallpaper.thumbnailUrl, _uncropped);
  });

  test('normalizes cached tiny URLs after feed cache decode', () {
    final PexelsFeedItem cached =
        decodeFeedItem(<String, dynamic>{
              'type': 'pexels',
              'id': '1563016',
              'wallpaper': <String, dynamic>{
                'core': <String, dynamic>{
                  'id': '1563016',
                  'source': 'pexels',
                  'fullUrl': 'https://images.pexels.com/photos/1563016/pexels-photo-1563016.jpeg',
                  'thumbnailUrl': _tiny,
                },
              },
            })!
            as PexelsFeedItem;

    expect(cached.wallpaper.thumbnailUrl, _uncropped);
  });
}
