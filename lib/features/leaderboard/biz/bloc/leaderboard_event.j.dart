part of 'leaderboard_bloc.j.dart';

@freezed
abstract class LeaderboardEvent with _$LeaderboardEvent {
  const factory LeaderboardEvent.started() = _Started;
  const factory LeaderboardEvent.tabChanged(LeaderboardTab tab) = _TabChanged;
  const factory LeaderboardEvent.refreshed() = _Refreshed;
}
