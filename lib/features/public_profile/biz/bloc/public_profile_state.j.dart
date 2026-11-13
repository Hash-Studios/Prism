part of 'public_profile_bloc.j.dart';

@freezed
abstract class PublicProfileState with _$PublicProfileState {
  const factory PublicProfileState({
    required LoadStatus status,
    required String profileId,
    required List<PublicProfileWallEntity> walls,
    required bool hasMoreWalls,
    required bool isFetchingMoreWalls,
    required RelationList followers,
    required RelationList following,

    /// Follow state the user asked for, keyed by profile UID. It wins over the profile stream until the
    /// request fails, so the button flips at once.
    @Default(<String, bool>{}) Map<String, bool> followOverrides,

    /// Result of the latest follow request. The UI shows a toast once per [FollowOutcome.id].
    FollowOutcome? followOutcome,
  }) = _PublicProfileState;

  const PublicProfileState._();

  factory PublicProfileState.initial() => const PublicProfileState(
    status: LoadStatus.initial,
    profileId: '',
    walls: <PublicProfileWallEntity>[],
    hasMoreWalls: true,
    isFetchingMoreWalls: false,
    followers: RelationList(),
    following: RelationList(),
  );

  RelationList relation(UserRelationKind kind) => kind == UserRelationKind.followers ? followers : following;
}

/// One paginated, searchable follower or following list.
@freezed
abstract class RelationList with _$RelationList {
  const factory RelationList({
    @Default(<UserSummaryEntity>[]) List<UserSummaryEntity> summaries,

    /// Where the next page starts. Null before the first page and after the last one.
    RelationCursor? next,

    /// Pages loaded since the list opened or last refreshed.
    @Default(0) int pages,
    @Default(false) bool isFetching,

    /// The last page request failed. The list shows a retry row.
    @Default(false) bool failed,

    /// Active search results. `null` means no search is active.
    List<UserSummaryEntity>? searchResults,
    @Default(false) bool isSearching,
  }) = _RelationList;

  const RelationList._();

  bool get hasMore => pages == 0 || next != null;

  RelationList withFollowState(String userId, {required bool isFollowed}) {
    List<UserSummaryEntity> update(List<UserSummaryEntity> users) =>
        users.map((u) => u.id == userId ? u.copyWith(isFollowedByCurrentUser: isFollowed) : u).toList(growable: false);
    final List<UserSummaryEntity>? results = searchResults;
    return copyWith(summaries: update(summaries), searchResults: results == null ? null : update(results));
  }
}

@freezed
abstract class FollowOutcome with _$FollowOutcome {
  const factory FollowOutcome({
    required int id,
    required bool follow,
    required bool success,
    @Default('') String targetName,
    @Default('') String targetUserId,
  }) = _FollowOutcome;
}
