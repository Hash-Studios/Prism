import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_facts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WallpaperCore _core(WallpaperSource source, {String? author, String? email}) => WallpaperCore(
  id: 'ab12',
  source: source,
  fullUrl: 'https://example.com/full.jpg',
  thumbnailUrl: 'https://example.com/thumb.jpg',
  authorName: author,
  authorEmail: email,
);

void main() {
  group('detailAuthor', () {
    test('Prism falls back to the email when the name is blank', () {
      final FeedItemEntity entity = FeedItemEntity.prism(
        id: 'ab12',
        wallpaper: PrismWallpaper(
          core: _core(WallpaperSource.prism, author: ' ', email: 'a@b.co'),
        ),
      );
      expect(detailAuthor(entity), 'a@b.co');
      expect(detailTitle(entity), 'AB12');
    });

    test('Wallhaven and Pexels use their own creator fields', () {
      final FeedItemEntity wallhaven = FeedItemEntity.wallhaven(
        id: 'ab12',
        wallpaper: WallhavenWallpaper(core: _core(WallpaperSource.wallhaven, author: 'Kira')),
      );
      final FeedItemEntity pexels = FeedItemEntity.pexels(
        id: 'ab12',
        wallpaper: PexelsWallpaper(core: _core(WallpaperSource.pexels), photographer: 'Lee'),
      );
      expect(detailAuthor(wallhaven), 'Kira');
      expect(detailAuthor(pexels), 'Lee');
    });

    test('no creator gives null', () {
      final FeedItemEntity entity = FeedItemEntity.pexels(
        id: 'ab12',
        wallpaper: PexelsWallpaper(core: _core(WallpaperSource.pexels)),
      );
      expect(detailAuthor(entity), isNull);
    });
  });

  testWidgets('facts for a Wallhaven wallpaper list only what the source has', (tester) async {
    const FeedItemEntity entity = FeedItemEntity.wallhaven(
      id: 'ab12',
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(
          id: 'ab12',
          source: WallpaperSource.wallhaven,
          fullUrl: 'https://example.com/full.jpg',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          resolution: '3840x2160',
          category: 'general',
          favourites: 12,
        ),
        views: 340,
        sizeBytes: 4200000,
      ),
    );
    late List<DetailFact> facts;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            facts = detailFacts(context, entity, const WallpaperDetailLoaded(entity: entity));
            return Scaffold(body: DetailFactsGrid(facts: facts));
          },
        ),
      ),
    );

    expect(facts.map((f) => f.label), <String>['Views', 'Favourites', 'Size', 'Resolution', 'Category', 'Source']);
    expect(find.text('340'), findsOneWidget);
    expect(find.text('4.20 MB'), findsOneWidget);
    expect(find.text('Wallhaven'), findsOneWidget);
  });

  testWidgets('a fact that is still loading shows a skeleton instead of a value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DetailFactsGrid(facts: <DetailFact>[DetailFact(label: 'Views', loading: true)]),
        ),
      ),
    );

    expect(find.text('Views'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
