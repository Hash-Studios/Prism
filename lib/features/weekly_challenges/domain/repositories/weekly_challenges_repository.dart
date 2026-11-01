import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';

abstract class WeeklyChallengesRepository {
  Future<List<WeeklyChallenge>> list({required bool past});
  Future<ChallengeDetail> get(String challengeId, ChallengeSort sort);
  Future<({bool voted, int voteCount})> setVote(String challengeId, String entryId, {required bool vote});
}
