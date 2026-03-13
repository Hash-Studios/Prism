part of 'public_profile_bloc.j.dart';

@freezed
abstract class PublicProfileEvent with _$PublicProfileEvent {
  const factory PublicProfileEvent.started({required String email}) = _Started;
  const factory PublicProfileEvent.refreshRequested() = _RefreshRequested;
  const factory PublicProfileEvent.fetchMoreWallsRequested() = _FetchMoreWallsRequested;
  const factory PublicProfileEvent.fetchMoreSetupsRequested() = _FetchMoreSetupsRequested;
  const factory PublicProfileEvent.followRequested({required String currentUserId, required String currentUserEmail}) =
      _FollowRequested;
  const factory PublicProfileEvent.unfollowRequested({
    required String currentUserId,
    required String currentUserEmail,
  }) = _UnfollowRequested;
  const factory PublicProfileEvent.linksUpdated({required String userId, required Map<String, String> links}) =
      _LinksUpdated;

  /// Load the profile summaries for a list of follower emails.
  const factory PublicProfileEvent.fetchFollowerSummariesRequested({
    required List<String> emails,
    required String currentUserEmail,
  }) = _FetchFollowerSummariesRequested;

  /// Load the profile summaries for a list of following emails.
  const factory PublicProfileEvent.fetchFollowingSummariesRequested({
    required List<String> emails,
    required String currentUserEmail,
  }) = _FetchFollowingSummariesRequested;

  /// Toggle follow status for a user shown in a list screen.
  const factory PublicProfileEvent.followFromListRequested({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) = _FollowFromListRequested;

  /// Toggle unfollow status for a user shown in a list screen.
  const factory PublicProfileEvent.unfollowFromListRequested({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) = _UnfollowFromListRequested;
}
