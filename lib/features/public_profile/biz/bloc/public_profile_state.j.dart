part of 'public_profile_bloc.j.dart';

@freezed
abstract class PublicProfileState with _$PublicProfileState {
  const factory PublicProfileState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required String email,
    required PublicProfileEntity profile,
    required List<PublicProfileWallEntity> walls,
    required List<PublicProfileSetupEntity> setups,
    required bool hasMoreWalls,
    required bool hasMoreSetups,
    required String? wallsCursor,
    required String? setupsCursor,
    required bool isFetchingMoreWalls,
    required bool isFetchingMoreSetups,

    /// Follower profiles loaded for the followers list screen (paginated).
    required List<UserSummaryEntity> followerSummaries,

    /// Following profiles loaded for the following list screen (paginated).
    required List<UserSummaryEntity> followingSummaries,

    /// Whether follower summaries are currently being loaded/searched.
    required bool isFetchingFollowers,

    /// Whether following summaries are currently being loaded/searched.
    required bool isFetchingFollowing,

    /// Current page loaded for followers (zero-indexed).
    required int followerPage,

    /// Current page loaded for following (zero-indexed).
    required int followingPage,

    /// Whether more follower pages are available.
    required bool hasMoreFollowers,

    /// Whether more following pages are available.
    required bool hasMoreFollowing,

    /// Active follower search results. `null` means no search is active.
    List<UserSummaryEntity>? followerSearchResults,

    /// Active following search results. `null` means no search is active.
    List<UserSummaryEntity>? followingSearchResults,

    /// Whether a follower search is in progress.
    required bool isSearchingFollowers,

    /// Whether a following search is in progress.
    required bool isSearchingFollowing,

    Failure? failure,
  }) = _PublicProfileState;

  factory PublicProfileState.initial() => const PublicProfileState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    email: '',
    profile: PublicProfileEntity.empty,
    walls: <PublicProfileWallEntity>[],
    setups: <PublicProfileSetupEntity>[],
    hasMoreWalls: true,
    hasMoreSetups: true,
    wallsCursor: null,
    setupsCursor: null,
    isFetchingMoreWalls: false,
    isFetchingMoreSetups: false,
    followerSummaries: <UserSummaryEntity>[],
    followingSummaries: <UserSummaryEntity>[],
    isFetchingFollowers: false,
    isFetchingFollowing: false,
    followerPage: 0,
    followingPage: 0,
    hasMoreFollowers: false,
    hasMoreFollowing: false,
    followerSearchResults: null,
    followingSearchResults: null,
    isSearchingFollowers: false,
    isSearchingFollowing: false,
  );
}
