part of 'category_feed_bloc.j.dart';

@freezed
abstract class CategoryFeedEvent with _$CategoryFeedEvent {
  const factory CategoryFeedEvent.started() = _Started;
  const factory CategoryFeedEvent.categorySelected({required CategoryEntity category}) = _CategorySelected;
  const factory CategoryFeedEvent.fetchMoreRequested() = _FetchMoreRequested;
  const factory CategoryFeedEvent.refreshRequested() = _RefreshRequested;
  const factory CategoryFeedEvent.blockedCreatorsChanged({required Set<String> blocked}) = _BlockedCreatorsChanged;
}
