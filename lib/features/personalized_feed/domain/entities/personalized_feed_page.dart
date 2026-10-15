import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

class PersonalizedFeedPage {
  const PersonalizedFeedPage({
    required this.items,
    required this.hasMore,
    this.usedKeys = const <String>[],
    this.isStale = false,
  });

  final List<FeedItemEntity> items;
  final bool hasMore;
  final List<String> usedKeys;

  /// For a cached page: it is older than the cache lifetime.
  final bool isStale;
}
