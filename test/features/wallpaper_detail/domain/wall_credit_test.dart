import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/wall_credit.dart';
import 'package:flutter_test/flutter_test.dart';

WallpaperCore _core({
  required String id,
  required WallpaperSource source,
  String? authorName,
  String? authorUid,
  String? authorPhoto,
}) => WallpaperCore(
  id: id,
  source: source,
  fullUrl: 'https://img.test/$id.jpg',
  thumbnailUrl: 'https://img.test/$id-thumb.jpg',
  authorName: authorName,
  authorUid: authorUid,
  authorPhoto: authorPhoto,
);

void main() {
  test('a creator wall credits the creator and opens their profile', () {
    final FeedItemEntity entity = FeedItemEntity.prism(
      id: 'prism-1',
      wallpaper: PrismWallpaper(
        core: _core(
          id: 'prism-1',
          source: WallpaperSource.prism,
          authorName: 'Ana',
          authorUid: 'ana-uid',
          authorPhoto: 'https://img.test/ana.jpg',
        ),
      ),
    );

    final WallCredit credit = WallCredit.of(entity);

    expect(credit.provenance, WallProvenance.creator);
    expect(credit.provenance.isPrismExclusive, isTrue);
    expect(credit.name, 'Ana');
    expect(credit.photoUrl, 'https://img.test/ana.jpg');
    expect(credit.profileUid, 'ana-uid');
    expect(credit.externalUrl, isNull);
  });

  test('a Studio wall credits Hash Studios and opens the Studio profile', () {
    final FeedItemEntity entity = FeedItemEntity.prism(
      id: 'prism-2',
      wallpaper: PrismWallpaper(
        core: _core(id: 'prism-2', source: WallpaperSource.prism, authorName: 'Someone', authorUid: 'someone-uid'),
        byStudio: true,
      ),
    );

    final WallCredit credit = WallCredit.of(entity);

    expect(credit.provenance, WallProvenance.studio);
    expect(credit.provenance.isPrismExclusive, isTrue);
    expect(credit.name, isNull);
    expect(credit.profileUid, 'prism-studio');
    expect(WallCredit.studioProfileUid, 'prism-studio');
    expect(credit.externalUrl, isNull);
  });

  test('an AI creator wall stays a creator credit', () {
    final FeedItemEntity entity = FeedItemEntity.prism(
      id: 'prism-3',
      wallpaper: PrismWallpaper(
        core: _core(id: 'prism-3', source: WallpaperSource.prism, authorName: 'Ana', authorUid: 'ana-uid'),
        isAiGenerated: true,
      ),
    );

    final WallCredit credit = WallCredit.of(entity);

    expect(credit.provenance, WallProvenance.creator);
    expect(credit.provenance.isPrismExclusive, isTrue);
    expect(credit.name, 'Ana');
    expect(credit.profileUid, 'ana-uid');
  });

  test('a Pexels wall credits the photographer with an https link', () {
    final FeedItemEntity entity = FeedItemEntity.pexels(
      id: 'px-1',
      wallpaper: PexelsWallpaper(
        core: _core(id: 'px-1', source: WallpaperSource.pexels),
        photographer: 'Lee',
        photographerUrl: 'https://www.pexels.com/@lee',
      ),
    );

    final WallCredit credit = WallCredit.of(entity);

    expect(credit.provenance, WallProvenance.pexels);
    expect(credit.provenance.isPrismExclusive, isFalse);
    expect(credit.name, 'Lee');
    expect(credit.externalUrl.toString(), 'https://www.pexels.com/@lee');
    expect(credit.profileUid, isNull);
  });

  test('a Pexels wall with a javascript link has no external link', () {
    final FeedItemEntity entity = FeedItemEntity.pexels(
      id: 'px-2',
      wallpaper: PexelsWallpaper(
        core: _core(id: 'px-2', source: WallpaperSource.pexels),
        photographer: 'Lee',
        photographerUrl: 'javascript:alert(1)',
      ),
    );

    final WallCredit credit = WallCredit.of(entity);

    expect(credit.name, 'Lee');
    expect(credit.externalUrl, isNull);
  });

  test('a Wallhaven wall links the uploader on wallhaven.cc', () {
    final FeedItemEntity entity = FeedItemEntity.wallhaven(
      id: 'wh-1',
      wallpaper: WallhavenWallpaper(
        core: _core(id: 'wh-1', source: WallpaperSource.wallhaven, authorName: 'kit'),
      ),
    );

    final WallCredit credit = WallCredit.of(entity);

    expect(credit.provenance, WallProvenance.wallhaven);
    expect(credit.provenance.isPrismExclusive, isFalse);
    expect(credit.name, 'kit');
    expect(credit.externalUrl.toString(), 'https://wallhaven.cc/user/kit');
    expect(credit.profileUid, isNull);
  });

  test('a Wallhaven wall with no author has no name and no link', () {
    final FeedItemEntity entity = FeedItemEntity.wallhaven(
      id: 'wh-2',
      wallpaper: WallhavenWallpaper(
        core: _core(id: 'wh-2', source: WallpaperSource.wallhaven),
      ),
    );

    final WallCredit credit = WallCredit.of(entity);

    expect(credit.provenance, WallProvenance.wallhaven);
    expect(credit.name, isNull);
    expect(credit.externalUrl, isNull);
  });
}
