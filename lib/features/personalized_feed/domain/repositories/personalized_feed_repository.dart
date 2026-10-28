import 'package:Prism/core/personalization/taste_profile.dart';
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

  /// Loads page one now and keeps it. The next page-one refresh [fetch] with the same user, taste, filters and mix
  /// takes it, or joins it while it loads. Null when the load fails; it never throws.
  Future<PersonalizedFeedPage?> primeFirstPage();

  /// A matching live prime, or the first page from the disk cache. It waits for the initial blocked-creator list,
  /// so blocked creators never show. A disk read makes no network call for the feed.
  Future<PersonalizedFeedPage?> readCached();

  /// Starts the [readCached] disk read now. The next [readCached] call for the same user takes its result.
  void warmCache();

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

  /// The user's taste from their picks, follows and signals, for ranking walls outside the feed.
  TasteProfile currentTasteProfile();
}
