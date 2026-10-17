part of 'leaderboard_bloc.j.dart';

enum LeaderboardTab { friends, global }

@freezed
abstract class LeaderboardState with _$LeaderboardState {
  const factory LeaderboardState({
    required LeaderboardTab tab,
    required LoadStatus friendsStatus,
    required LoadStatus globalStatus,
    required List<LeaderboardEntry> friends,
    required List<LeaderboardEntry> global,
  }) = _LeaderboardState;

  factory LeaderboardState.initial() => const LeaderboardState(
    tab: LeaderboardTab.friends,
    friendsStatus: LoadStatus.initial,
    globalStatus: LoadStatus.initial,
    friends: <LeaderboardEntry>[],
    global: <LeaderboardEntry>[],
  );
}

extension LeaderboardStateTab on LeaderboardState {
  LoadStatus get status => tab == LeaderboardTab.friends ? friendsStatus : globalStatus;
  List<LeaderboardEntry> get entries => tab == LeaderboardTab.friends ? friends : global;
}
