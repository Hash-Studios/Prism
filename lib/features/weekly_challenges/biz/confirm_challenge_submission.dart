import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/features/weekly_challenges/domain/repositories/weekly_challenges_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ConfirmChallengeSubmission {
  ConfirmChallengeSubmission(this._repository);
  final WeeklyChallengesRepository _repository;
  Future<void> call({required String uid, required String challengeId, required String wallId}) async {
    for (final delay in const [Duration.zero, Duration(seconds: 1), Duration(seconds: 3)]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      if (!app_state.prismUser.loggedIn || app_state.prismUser.id != uid) return;
      try {
        final detail = await _repository.get(challengeId, ChallengeSort.top);
        if (detail.myAdmittedWallIds.contains(wallId)) return;
      } catch (_) {
        return;
      }
    }
  }
}
