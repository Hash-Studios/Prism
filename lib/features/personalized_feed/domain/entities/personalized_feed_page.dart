import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

class PersonalizedFeedPage {
  const PersonalizedFeedPage({required this.items, required this.hasMore, this.usedKeys = const <String>[]});

  final List<FeedItemEntity> items;
  final bool hasMore;
  final List<String> usedKeys;
}
