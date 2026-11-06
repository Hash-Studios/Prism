import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Wallhaven wall. Walls with the same [picture] are one picture uploaded under different ids.
FeedItemEntity _wall(String id, {String picture = ''}) => FeedItemEntity.wallhaven(
  id: id,
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://w.wallhaven.cc/full/$id.jpg',
      thumbnailUrl: 'https://th.wallhaven.cc/small/$id.jpg',
      sizeBytes: 17913092 + id.length,
    ),
    dimensionX: 3840,
    dimensionY: 5238,
    colors: <String>[if (picture.isEmpty) id else picture],
  ),
);

void main() {
  test('More like this drops the open wall, repeats and re-uploads on every page, the first copy kept', () {
    final FeedItemEntity current = _wall('open', picture: 'samurai');
    final RecommendationState first = const RecommendationState.initial().append(
      RecommendationPage(
        items: <FeedItemEntity>[
          _wall('a'),
          _wall('open-again', picture: 'samurai'),
          _wall('b', picture: 'storm'),
          _wall('b2', picture: 'storm'),
          _wall('a'),
        ],
        kind: RecommendationKind.related,
        nextCursor: const ExternalRecommendationCursor(2),
      ),
      current,
    );
    expect(first.items.map((FeedItemEntity wall) => wall.id), <String>['a', 'b']);

    final RecommendationState next = first.loadingPage().append(
      RecommendationPage(
        items: <FeedItemEntity>[
          _wall('b3', picture: 'storm'),
          _wall('a'),
          _wall('c'),
          _wall('open'),
        ],
        kind: RecommendationKind.related,
      ),
      current,
    );
    expect(next.items.map((FeedItemEntity wall) => wall.id), <String>['a', 'b', 'c']);
    expect(next.status, RecommendationStatus.exhausted);
  });
}
