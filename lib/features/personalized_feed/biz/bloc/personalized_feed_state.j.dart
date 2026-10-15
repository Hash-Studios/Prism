part of 'personalized_feed_bloc.j.dart';

@freezed
abstract class PersonalizedFeedState with _$PersonalizedFeedState {
  const factory PersonalizedFeedState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required List<FeedItemEntity> items,
    required bool hasMore,
    required bool isFetchingMore,
    required int page,
    required List<String> seenKeys,
    required HomeFeedChip chip,

    /// Cached items are on screen while the fresh page loads.
    required bool isRefreshing,

    /// The last refresh failed. Items from before it stay on screen.
    required bool refreshFailed,
    Failure? failure,
  }) = _PersonalizedFeedState;

  factory PersonalizedFeedState.initial() => const PersonalizedFeedState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    items: <FeedItemEntity>[],
    hasMore: true,
    isFetchingMore: false,
    page: 0,
    seenKeys: <String>[],
    chip: HomeFeedChip.forYou,
    isRefreshing: false,
    refreshFailed: false,
  );
}
