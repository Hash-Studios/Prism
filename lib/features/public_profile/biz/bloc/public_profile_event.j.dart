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

  /// Load a page of follower summaries. [page] is zero-indexed; [pageSize]
  /// defaults to 20. Pass [page] = 0 for the initial load.
  const factory PublicProfileEvent.fetchFollowerSummariesPageRequested({
    required List<String> allEmails,
    required String currentUserEmail,
    required int page,
    @Default(20) int pageSize,
  }) = _FetchFollowerSummariesPageRequested;

  /// Load a page of following summaries. [page] is zero-indexed.
  const factory PublicProfileEvent.fetchFollowingSummariesPageRequested({
    required List<String> allEmails,
    required String currentUserEmail,
    required int page,
    @Default(20) int pageSize,
  }) = _FetchFollowingSummariesPageRequested;

  /// Search followers by username prefix. Results are scoped to [allEmails].
  const factory PublicProfileEvent.searchFollowerSummariesRequested({
    required String query,
    required List<String> allEmails,
    required String currentUserEmail,
  }) = _SearchFollowerSummariesRequested;

  /// Search following list by username prefix. Results are scoped to [allEmails].
  const factory PublicProfileEvent.searchFollowingSummariesRequested({
    required String query,
    required List<String> allEmails,
    required String currentUserEmail,
  }) = _SearchFollowingSummariesRequested;

  /// Clear active follower search results (return to paginated list).
  const factory PublicProfileEvent.clearFollowerSearch() = _ClearFollowerSearch;

  /// Clear active following search results (return to paginated list).
  const factory PublicProfileEvent.clearFollowingSearch() = _ClearFollowingSearch;

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
