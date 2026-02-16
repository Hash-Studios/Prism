part of 'category_feed_bloc.j.dart';

@freezed
abstract class CategoryFeedState with _$CategoryFeedState {
  const factory CategoryFeedState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required List<CategoryEntity> categories,
    required CategoryEntity? selectedCategory,
    required List<FeedItemEntity> items,
    required bool hasMore,
    required String? nextCursor,
    required bool isFetchingMore,
    Failure? failure,
  }) = _CategoryFeedState;

  factory CategoryFeedState.initial() => const CategoryFeedState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        categories: <CategoryEntity>[],
        selectedCategory: null,
        items: <FeedItemEntity>[],
        hasMore: true,
        nextCursor: null,
        isFetchingMore: false,
      );
}
