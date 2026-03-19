part of 'personalized_feed_bloc.j.dart';

@freezed
abstract class PersonalizedFeedEvent with _$PersonalizedFeedEvent {
  const factory PersonalizedFeedEvent.started() = _Started;
  const factory PersonalizedFeedEvent.refreshRequested() = _RefreshRequested;
  const factory PersonalizedFeedEvent.fetchMoreRequested() = _FetchMoreRequested;
  const factory PersonalizedFeedEvent.retryRequested() = _RetryRequested;
}
