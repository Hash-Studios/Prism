part of 'public_profile_bloc.dart';

@freezed
abstract class PublicProfileEvent with _$PublicProfileEvent {
  const factory PublicProfileEvent.started({required String email}) = _Started;
  const factory PublicProfileEvent.refreshRequested() = _RefreshRequested;
  const factory PublicProfileEvent.fetchMoreWallsRequested() =
      _FetchMoreWallsRequested;
  const factory PublicProfileEvent.fetchMoreSetupsRequested() =
      _FetchMoreSetupsRequested;
  const factory PublicProfileEvent.followRequested({
    required String currentUserId,
    required String currentUserEmail,
  }) = _FollowRequested;
  const factory PublicProfileEvent.unfollowRequested({
    required String currentUserId,
    required String currentUserEmail,
  }) = _UnfollowRequested;
  const factory PublicProfileEvent.linksUpdated({
    required String userId,
    required Map<String, String> links,
  }) = _LinksUpdated;
}
