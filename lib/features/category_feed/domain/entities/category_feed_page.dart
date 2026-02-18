import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

class CategoryFeedPage {
  const CategoryFeedPage({required this.items, required this.hasMore, this.nextCursor});

  final List<FeedItemEntity> items;
  final bool hasMore;
  final String? nextCursor;
}
