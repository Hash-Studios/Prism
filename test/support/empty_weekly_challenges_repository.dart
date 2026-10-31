import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/features/weekly_challenges/domain/repositories/weekly_challenges_repository.dart';

/// No active challenges, for Home tests that exercise other features.
class EmptyWeeklyChallengesRepository implements WeeklyChallengesRepository {
  const EmptyWeeklyChallengesRepository();

  @override
  Future<List<WeeklyChallenge>> list({required bool past}) async => const <WeeklyChallenge>[];

  @override
  Future<ChallengeDetail> get(String challengeId, ChallengeSort sort) =>
      throw StateError('No challenge exists in this fixture');

  @override
  Future<({bool voted, int voteCount})> setVote(String challengeId, String entryId, {required bool vote}) =>
      throw StateError('No challenge exists in this fixture');
}
