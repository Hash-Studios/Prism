import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

/// Filters Prism-hosted content by blocked creator email (normalized lowercase).
class BlockedCreatorsFilter {
  BlockedCreatorsFilter._();

  static String normalizeEmail(String? email) => (email ?? '').trim().toLowerCase();

  static bool hidesCreatorEmail(String? creatorEmail, Set<String> blockedEmailsLowercase) {
    if (blockedEmailsLowercase.isEmpty) {
      return false;
    }
    final String n = normalizeEmail(creatorEmail);
    return n.isNotEmpty && blockedEmailsLowercase.contains(n);
  }

  /// Whether a [FeedItemEntity] should be hidden because its creator is
  /// blocked. Only Prism-hosted items carry a creator email; other sources
  /// are never hidden.
  static bool hidesFeedItem(FeedItemEntity item, Set<String> blockedEmailsLowercase) {
    if (blockedEmailsLowercase.isEmpty) {
      return false;
    }
    return item.maybeWhen(
      prism: (_, wall) => hidesCreatorEmail(wall.core.authorEmail, blockedEmailsLowercase),
      orElse: () => false,
    );
  }

  /// Filters a feed list, dropping items from blocked creators.
  static List<FeedItemEntity> filterFeedItems(List<FeedItemEntity> items, Set<String> blockedEmailsLowercase) {
    if (blockedEmailsLowercase.isEmpty) {
      return items;
    }
    return items.where((FeedItemEntity item) => !hidesFeedItem(item, blockedEmailsLowercase)).toList(growable: false);
  }
}
