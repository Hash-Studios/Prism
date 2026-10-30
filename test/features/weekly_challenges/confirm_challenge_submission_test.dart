import 'package:Prism/core/constants/app_constants.dart' as constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/weekly_challenges/biz/confirm_challenge_submission.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'weekly_challenges_cubit_test.dart' show Repository, challenge;

class AdmissionRepository extends Repository {
  int reads = 0;
  @override
  Future<ChallengeDetail> get(String id, ChallengeSort sort) async {
    reads++;
    return ChallengeDetail(challenge: challenge(), entries: [], myEntryCount: 1, myAdmittedWallIds: ['wall_ai']);
  }
}

void main() {
  setUp(() {
    app_state.prismUser = constants.createGuestPrismUser()
      ..id = 'creator'
      ..loggedIn = true;
  });
  tearDown(() {
    app_state.prismUser = constants.createGuestPrismUser();
  });
  test('fresh read confirms pending admission without needing a visible approved entry', () async {
    final repo = AdmissionRepository();
    await ConfirmChallengeSubmission(repo)(uid: 'creator', challengeId: '2026-10-26', wallId: 'wall_ai');
    expect(repo.reads, 1);
  });
  test('an account change prevents confirmation work for the prior owner', () async {
    final repo = AdmissionRepository();
    await ConfirmChallengeSubmission(repo)(uid: 'prior-owner', challengeId: '2026-10-26', wallId: 'wall_ai');
    expect(repo.reads, 0);
  });
}
