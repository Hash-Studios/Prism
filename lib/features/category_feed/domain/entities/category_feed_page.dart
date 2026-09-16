import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

class CategoryFeedPage {
  const CategoryFeedPage({required this.items, required this.hasMore});

  final List<FeedItemEntity> items;
  final bool hasMore;
}
