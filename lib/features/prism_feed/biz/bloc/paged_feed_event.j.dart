part of 'paged_feed_bloc.j.dart';

@freezed
abstract class PagedFeedEvent with _$PagedFeedEvent {
  const factory PagedFeedEvent.started() = _Started;
  const factory PagedFeedEvent.refreshRequested() = _RefreshRequested;
  const factory PagedFeedEvent.fetchMoreRequested() = _FetchMoreRequested;
}
