import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

WallpaperCore _core(String id, WallpaperSource source) =>
    WallpaperCore(id: id, source: source, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: 't');

FeedItemEntity _prism(String id, {bool isAiGenerated = false, Map<String, Object?>? aiMetadata}) => PrismFeedItem(
  id: id,
  wallpaper: PrismWallpaper(
    core: _core(id, WallpaperSource.prism),
    isAiGenerated: isAiGenerated,
    aiMetadata: aiMetadata,
  ),
);

void main() {
  test('AI walls show until the user turns the setting off', () async {
    final settings = SettingsLocalDataSource(InMemoryLocalStore());
    expect(AiContentFilter.showsAi(settings), isTrue);

    expect(await AiContentFilter.setShowsAi(settings, false), isTrue);
    expect(AiContentFilter.showsAi(settings), isFalse);
    expect(await AiContentFilter.setShowsAi(settings, false), isFalse);

    expect(await AiContentFilter.setShowsAi(settings, true), isTrue);
    expect(AiContentFilter.showsAi(settings), isTrue);
  });

  test('a Prism wall is AI when its flag is set or it carries AI metadata', () {
    final List<FeedItemEntity> items = <FeedItemEntity>[
      _prism('flag', isAiGenerated: true),
      _prism('metadata', aiMetadata: <String, Object?>{'prompt': 'a neon city'}),
      _prism('empty-metadata', aiMetadata: <String, Object?>{}),
      _prism('human'),
      WallhavenFeedItem(
        id: 'wh',
        wallpaper: WallhavenWallpaper(core: _core('wh', WallpaperSource.wallhaven)),
      ),
    ];

    expect(AiContentFilter.filterFeedItems(items, showAi: false).map((item) => item.id), <String>[
      'empty-metadata',
      'human',
      'wh',
    ]);
    expect(AiContentFilter.filterFeedItems(items, showAi: true), same(items));
  });

  test('the wall DTO reads isAiGenerated and aiModel, and defaults to a human wall', () {
    final PrismWallpaper ai = PrismWallDocDto.fromJson(<String, dynamic>{
      'isAiGenerated': true,
      'aiModel': ' Seedream 5 Lite ',
    }).toDomain(docId: 'ai');
    expect(ai.isAiGenerated, isTrue);
    expect(ai.aiModel, 'Seedream 5 Lite');

    final PrismWallpaper human = PrismWallDocDto.fromJson(<String, dynamic>{'aiModel': ''}).toDomain(docId: 'h');
    expect(human.isAiGenerated, isFalse);
    expect(human.aiModel, isNull);
    expect(AiContentFilter.isAi(human), isFalse);
  });

  test('the feed cache keeps the AI flag and model', () {
    final FeedItemEntity? decoded = decodeFeedItem(
      encodeFeedItem(
        PrismFeedItem(
          id: 'ai',
          wallpaper: PrismWallpaper(core: _core('ai', WallpaperSource.prism), isAiGenerated: true, aiModel: 'Z-Image'),
        ),
      ),
    );
    final PrismWallpaper wall = (decoded! as PrismFeedItem).wallpaper;
    expect(wall.isAiGenerated, isTrue);
    expect(wall.aiModel, 'Z-Image');

    final PrismWallpaper legacy = (decodeFeedItem(encodeFeedItem(_prism('human')))! as PrismFeedItem).wallpaper;
    expect(legacy.isAiGenerated, isFalse);
    expect(legacy.aiModel, isNull);
  });
}
