import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore Prism walls cannot spoof an external provider', () {
    for (final provider in <String>['wallhaven', 'pexels', 'unknown', '']) {
      final wall = PrismWallDocDto.fromJson(<String, dynamic>{
        'wallpaper_provider': provider,
        'wallpaper_url': '',
        'wallpaper_thumb':
            'https://images.example.com/previews/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.img',
      }).toDomain(docId: 'w1');
      expect(wall.source, WallpaperSource.prism);
      expect(wall.fullUrl, isEmpty);
    }
  });

  test('protected feed and profile previews never substitute the thumbnail for the original', () {
    const thumb =
        'https://images.example.com/previews/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.img';
    final wall = PrismWallDocDto.fromJson(<String, dynamic>{
      'originalProtected': true,
      'originalObjectId': 'g1',
      'wallpaper_url': '',
      'wallpaper_thumb': thumb,
    }).toDomain(docId: 'w1');
    expect(wall.core.fullUrl, isEmpty);
    expect(wall.core.thumbnailUrl, thumb);
    final profile = const PublicProfileWallEntity(id: 'w1', wallpaperUrl: '', wallpaperThumb: thumb).toFeedItem();
    expect(profile.fullUrl, isEmpty);
    expect(profile.thumbnailUrl, thumb);
  });

  PrismWallDocDto dto({String category = '', List<String> tags = const <String>[]}) =>
      PrismWallDocDto(wallpaperUrl: 'https://x/y.jpg', category: category, tags: tags);

  test('merges AI category into tags', () {
    expect(dto(category: 'Space', tags: <String>['stars']).toDomain(docId: 'a').tags, <String>['stars', 'Space']);
  });

  test('General category leaves tags as-is', () {
    expect(dto(category: 'General', tags: <String>['stars']).toDomain(docId: 'a').tags, <String>['stars']);
    expect(dto(category: 'General').toDomain(docId: 'a').tags, isNull);
  });

  test('de-duplicates case-insensitively', () {
    expect(dto(category: 'space', tags: <String>['Space']).toDomain(docId: 'a').tags, <String>['Space']);
  });

  group('title', () {
    test('survives the JSON round trip', () {
      final PrismWallDocDto parsed = PrismWallDocDto.fromJson(<String, dynamic>{
        'wallpaper_url': 'https://x/y.jpg',
        'title': ' Night city ',
      });
      expect(PrismWallDocDto.fromJson(parsed.toJson()).title, ' Night city ');
      expect(parsed.toDomain(docId: 'a').title, 'Night city');
    });

    test('is null when the document has none or a blank one', () {
      expect(PrismWallDocDto.fromJson(<String, dynamic>{'wallpaper_url': 'https://x/y.jpg'}).title, isNull);
      expect(const PrismWallDocDto(wallpaperUrl: 'https://x/y.jpg', title: '  ').toDomain(docId: 'a').title, isNull);
      expect(dto().toDomain(docId: 'a').title, isNull);
    });
  });

  group('colors', () {
    test('are read from the document, most dominant first', () {
      final parsed = PrismWallDocDto.fromJson(<String, dynamic>{
        'wallpaper_url': 'https://x/y.jpg',
        'colors': <String>['blue', 'white'],
      });

      expect(parsed.toDomain(docId: 'a').colors, <String>['blue', 'white']);
    });

    test('are null when the wall has none', () {
      expect(dto().toDomain(docId: 'a').colors, isNull);
      expect(PrismWallDocDto.fromJson(<String, dynamic>{'wallpaper_url': 'https://x/y.jpg'}).colors, isEmpty);
    });
  });

  group('boostedUntil', () {
    test('is read from a millisecond timestamp', () {
      final parsed = PrismWallDocDto.fromJson(<String, dynamic>{
        'wallpaper_url': 'https://x/y.jpg',
        'boostedUntil': DateTime.utc(2030).millisecondsSinceEpoch,
      });

      expect(parsed.toDomain(docId: 'a').boostedUntil, DateTime.utc(2030));
    });

    test('is null when the wall was never boosted, and isBoostedAt follows the clock', () {
      expect(dto().toDomain(docId: 'a').boostedUntil, isNull);
      final wall = PrismWallDocDto(
        wallpaperUrl: 'https://x/y.jpg',
        boostedUntil: DateTime.utc(2030),
      ).toDomain(docId: 'a');
      expect(wall.isBoostedAt(DateTime.utc(2029)), isTrue);
      expect(wall.isBoostedAt(DateTime.utc(2031)), isFalse);
      expect(dto().toDomain(docId: 'a').isBoostedAt(DateTime.utc(2029)), isFalse);
    });
  });

  group('depth', () {
    PrismWallDocDto parsed(Object? depth) =>
        PrismWallDocDto.fromJson(<String, dynamic>{'wallpaper_url': 'https://x/y.jpg', 'depth': ?depth});

    test('maps the tier of each checked wall', () {
      expect(parsed(<String, Object?>{'tier': 'auto'}).toDomain(docId: 'a').depthTier, WallDepthTier.auto);
      expect(
        parsed(<String, Object?>{
          'tier': 'menu',
          'kind': 'person',
          'top': 0.31,
          'v': 1,
          'by': 'detector',
        }).toDomain(docId: 'a').depthTier,
        WallDepthTier.menu,
      );
      expect(parsed(<String, Object?>{'tier': 'none'}).toDomain(docId: 'a').depthTier, WallDepthTier.none);
    });

    test('is null when the wall was not checked or the tier is unknown', () {
      expect(parsed(null).toDomain(docId: 'a').depthTier, isNull);
      expect(parsed(<String, Object?>{}).toDomain(docId: 'a').depthTier, isNull);
      expect(parsed(<String, Object?>{'tier': 'sideways'}).toDomain(docId: 'a').depthTier, isNull);
      expect(parsed(<String, Object?>{'by': 'detector'}).toDomain(docId: 'a').depthTier, isNull);
      expect(dto().toDomain(docId: 'a').depthTier, isNull);
    });

    test('survives the JSON round trip', () {
      final PrismWallDocDto original = parsed(<String, Object?>{'tier': 'menu'});

      expect(PrismWallDocDto.fromJson(original.toJson()).toDomain(docId: 'a').depthTier, WallDepthTier.menu);
    });
  });
}
