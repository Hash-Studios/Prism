part of 'public_profile_bloc.j.dart';

@freezed
abstract class PublicProfileEvent with _$PublicProfileEvent {
  const factory PublicProfileEvent.started({required String identifier}) = _Started;
  const factory PublicProfileEvent.refreshRequested() = _RefreshRequested;
  const factory PublicProfileEvent.fetchMoreWallsRequested() = _FetchMoreWallsRequested;

  /// Load the next page of the [kind] list of [profileUid]. The first request loads the first page.
  const factory PublicProfileEvent.relationPageRequested({required UserRelationKind kind, required String profileUid}) =
      _RelationPageRequested;

  /// Reload the [kind] list of [profileUid] from the first page. A page that is still loading is dropped.
  const factory PublicProfileEvent.relationRefreshRequested({
    required UserRelationKind kind,
    required String profileUid,
  }) = _RelationRefreshRequested;

  /// Search the [kind] list of [profileUid] by username prefix: the newest edges plus the loaded pages.
  const factory PublicProfileEvent.relationSearchRequested({
    required UserRelationKind kind,
    required String query,
    required String profileUid,
  }) = _RelationSearchRequested;

  /// Clear active search results (return to the paginated list).
  const factory PublicProfileEvent.relationSearchCleared({required UserRelationKind kind}) = _RelationSearchCleared;

  /// Follow ([follow] true) or unfollow the target user and sync their posts topic.
  const factory PublicProfileEvent.followChangeRequested({
    required bool follow,
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
    @Default('') String targetName,
  }) = _FollowChangeRequested;
}
