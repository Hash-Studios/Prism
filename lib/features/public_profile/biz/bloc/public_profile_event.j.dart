part of 'public_profile_bloc.j.dart';

@freezed
abstract class PublicProfileEvent with _$PublicProfileEvent {
  const factory PublicProfileEvent.started({required String email}) = _Started;
  const factory PublicProfileEvent.refreshRequested() = _RefreshRequested;
  const factory PublicProfileEvent.fetchMoreWallsRequested() = _FetchMoreWallsRequested;

  /// Load a page of the [kind] list. [page] is zero-indexed; pass 0 for the initial load.
  const factory PublicProfileEvent.relationPageRequested({
    required UserRelationKind kind,
    required List<String> allEmails,
    required int page,
  }) = _RelationPageRequested;

  /// Search the [kind] list by username prefix. Results are scoped to [allEmails].
  const factory PublicProfileEvent.relationSearchRequested({
    required UserRelationKind kind,
    required String query,
    required List<String> allEmails,
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
  }) = _FollowChangeRequested;
}
