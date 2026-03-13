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

    /// Follower profiles loaded for the followers list screen.
    required List<UserSummaryEntity> followerSummaries,

    /// Following profiles loaded for the following list screen.
    required List<UserSummaryEntity> followingSummaries,

    /// Whether follower/following summaries are being loaded.
    required bool isFetchingSummaries,
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
    isFetchingSummaries: false,
  );
}
