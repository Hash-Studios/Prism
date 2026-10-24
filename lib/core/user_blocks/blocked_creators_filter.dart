import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

/// Filters Prism-hosted content by blocked creator UID.
class BlockedCreatorsFilter {
  BlockedCreatorsFilter._();

  static bool hidesCreatorUid(String? creatorUid, Set<String> blockedUids) {
    if (blockedUids.isEmpty) {
      return false;
    }
    final String uid = (creatorUid ?? '').trim();
    return uid.isNotEmpty && blockedUids.contains(uid);
  }

  /// Whether a [FeedItemEntity] should be hidden because its creator is
  /// blocked. Other sources are never hidden.
  static bool hidesFeedItem(FeedItemEntity item, Set<String> blockedUids) {
    if (blockedUids.isEmpty) {
      return false;
    }
    return item.maybeWhen(prism: (_, wall) => hidesCreatorUid(wall.core.authorUid, blockedUids), orElse: () => false);
  }

  /// Filters a feed list, dropping items from blocked creators.
  static List<FeedItemEntity> filterFeedItems(List<FeedItemEntity> items, Set<String> blockedUids) {
    if (blockedUids.isEmpty) {
      return items;
    }
    return items.where((FeedItemEntity item) => !hidesFeedItem(item, blockedUids)).toList(growable: false);
  }
}
