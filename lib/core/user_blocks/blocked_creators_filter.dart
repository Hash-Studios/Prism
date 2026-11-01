import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

/// Filters Prism-hosted content by blocked creator UID.
class BlockedCreatorsFilter {
  BlockedCreatorsFilter._();

  static bool hidesCreatorUid(String? creatorUid, BlockedCreators blocked) {
    final String uid = (creatorUid ?? '').trim();
    return uid.isNotEmpty && blocked.blocks(uid);
  }

  /// Whether a [FeedItemEntity] should be hidden because its creator is
  /// blocked. Other sources are never hidden.
  static bool hidesFeedItem(FeedItemEntity item, BlockedCreators blocked) =>
      item.maybeWhen(prism: (_, wall) => hidesCreatorUid(wall.core.authorUid, blocked), orElse: () => false);

  /// Filters a feed list, dropping items from blocked creators.
  static List<FeedItemEntity> filterFeedItems(List<FeedItemEntity> items, BlockedCreators blocked) {
    if (blocked case KnownBlockedCreators(uids: Set<String>(isEmpty: true))) {
      return items;
    }
    return items.where((FeedItemEntity item) => !hidesFeedItem(item, blocked)).toList(growable: false);
  }
}
