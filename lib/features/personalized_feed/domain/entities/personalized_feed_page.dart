import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

class PersonalizedFeedPage {
  const PersonalizedFeedPage({
    required this.items,
    required this.hasMore,
    this.usedKeys = const <String>[],
    this.sourceCounts = const <WallpaperSource, int>{},
  });

  final List<FeedItemEntity> items;
  final bool hasMore;
  final List<String> usedKeys;
  final Map<WallpaperSource, int> sourceCounts;
}
