import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';

class FetchPersonalizedFeedRequest {
  const FetchPersonalizedFeedRequest({
    required this.page,
    required this.refresh,
    required this.seenKeys,
    required this.existingItems,
  });

  final int page;
  final bool refresh;
  final List<String> seenKeys;
  final List<FeedItemEntity> existingItems;
}

const int _seenKeyWindow = 300;

/// Keeps the newest 300 seen keys.
List<String> trimSeenKeys(List<String> seen) =>
    seen.length <= _seenKeyWindow ? seen : seen.sublist(seen.length - _seenKeyWindow);

abstract class PersonalizedFeedRepository {
  Future<Result<PersonalizedFeedPage>> fetch(FetchPersonalizedFeedRequest request);

  /// The first page from the disk cache, or null when there is none. Reads at once: it does not wait for the block
  /// list, so the home feed can paint before any network call.
  Future<PersonalizedFeedPage?> readCached();

  /// Hides [item] for good and teaches the feed to show fewer like it.
  Future<void> lessLikeThis(FeedItemEntity item);

  /// Shows [item] again after [lessLikeThis].
  Future<void> undoLessLikeThis(FeedItemEntity item);

  /// Counts the wallpapers with these canonical [keys] as shown, so the ranker fades them out.
  Future<void> recordShown(Iterable<String> keys);

  /// New wallpapers from the creators the user follows. Page [page] holds the pages before it.
  Future<Result<PersonalizedFeedPage>> fetchFollowing({required int page});

  /// The most viewed wallpapers. One page, no paging.
  Future<Result<PersonalizedFeedPage>> fetchPopular();
}
