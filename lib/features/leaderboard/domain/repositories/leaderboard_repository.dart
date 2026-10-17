import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// The server's top list from `leaderboards/current`, best first.
  Future<Result<List<LeaderboardEntry>>> fetchGlobal();

  /// The people the user follows plus the user, best first. Only the first 90 emails are read.
  Future<Result<List<LeaderboardEntry>>> fetchFriends(List<String> followingEmails, String currentWeekKey);
}
