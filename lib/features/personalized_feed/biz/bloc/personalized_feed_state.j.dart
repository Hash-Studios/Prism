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
    required int sourcePrism,
    required int sourceWallhaven,
    required int sourcePexels,
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
    sourcePrism: 0,
    sourceWallhaven: 0,
    sourcePexels: 0,
  );
}
