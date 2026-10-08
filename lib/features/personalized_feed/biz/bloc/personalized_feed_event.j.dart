part of 'personalized_feed_bloc.j.dart';

@freezed
abstract class PersonalizedFeedEvent with _$PersonalizedFeedEvent {
  const factory PersonalizedFeedEvent.started() = _Started;
  const factory PersonalizedFeedEvent.refreshRequested() = _RefreshRequested;
  const factory PersonalizedFeedEvent.fetchMoreRequested() = _FetchMoreRequested;
  const factory PersonalizedFeedEvent.lessLikeThisRequested(FeedItemEntity item) = _LessLikeThisRequested;
  const factory PersonalizedFeedEvent.lessLikeThisUndone(FeedItemEntity item, {required int index}) =
      _LessLikeThisUndone;
  const factory PersonalizedFeedEvent.settingsChanged() = _SettingsChanged;
  const factory PersonalizedFeedEvent.chipSelected(HomeFeedChip chip) = _ChipSelected;
  const factory PersonalizedFeedEvent.tilesSeen(List<String> keys) = _TilesSeen;
  const factory PersonalizedFeedEvent.blockedCreatorsChanged({required Set<String> blocked}) = _BlockedCreatorsChanged;
}
