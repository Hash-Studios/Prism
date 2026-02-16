part of 'category_feed_bloc.dart';

@freezed
abstract class CategoryFeedEvent with _$CategoryFeedEvent {
  const factory CategoryFeedEvent.started() = _Started;
  const factory CategoryFeedEvent.categorySelected({
    required CategoryEntity category,
    @Default(true) bool refresh,
  }) = _CategorySelected;
  const factory CategoryFeedEvent.fetchMoreRequested() = _FetchMoreRequested;
  const factory CategoryFeedEvent.refreshRequested() = _RefreshRequested;
}
