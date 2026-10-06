part of 'public_profile_bloc.j.dart';

@freezed
abstract class PublicProfileState with _$PublicProfileState {
  const factory PublicProfileState({
    required LoadStatus status,
    required String email,
    required List<PublicProfileWallEntity> walls,
    required bool hasMoreWalls,
    required bool isFetchingMoreWalls,
    required RelationList followers,
    required RelationList following,

    /// Follow state the user asked for, keyed by lowercase email. It wins over the profile stream until the
    /// request fails, so the button flips at once.
    @Default(<String, bool>{}) Map<String, bool> followOverrides,

    /// Result of the latest follow request. The UI shows a toast once per [FollowOutcome.id].
    FollowOutcome? followOutcome,
  }) = _PublicProfileState;

  const PublicProfileState._();

  factory PublicProfileState.initial() => const PublicProfileState(
    status: LoadStatus.initial,
    email: '',
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
    @Default(false) bool isFetching,
    @Default(0) int page,
    @Default(false) bool hasMore,

    /// Active search results. `null` means no search is active.
    List<UserSummaryEntity>? searchResults,
    @Default(false) bool isSearching,
  }) = _RelationList;

  const RelationList._();

  RelationList withFollowState(String email, {required bool isFollowed}) {
    List<UserSummaryEntity> update(List<UserSummaryEntity> users) => users
        .map((u) => u.email.toLowerCase() == email.toLowerCase() ? u.copyWith(isFollowedByCurrentUser: isFollowed) : u)
        .toList(growable: false);
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
  }) = _FollowOutcome;
}
