part of 'paged_feed_bloc.j.dart';

@freezed
abstract class PagedFeedState with _$PagedFeedState {
  const factory PagedFeedState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required List<FeedItemEntity> items,
    required bool hasMore,
    required bool isFetchingMore,
    required int page,
    Failure? failure,
  }) = _PagedFeedState;

  factory PagedFeedState.initial() => const PagedFeedState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    items: <FeedItemEntity>[],
    hasMore: true,
    isFetchingMore: false,
    page: 0,
  );
}
