import 'package:Prism/features/ai_wallpaper/domain/ai_rollout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI off is never eligible', () {
    expect(aiRolloutEligible(aiEnabled: false, rolloutPercent: 100, loggedIn: true, userId: 'a'), isFalse);
  });

  test('a full rollout includes guests', () {
    expect(aiRolloutEligible(aiEnabled: true, rolloutPercent: 100, loggedIn: false, userId: ''), isTrue);
  });

  test('a partial rollout excludes guests and users outside the percent', () {
    expect(aiRolloutEligible(aiEnabled: true, rolloutPercent: 50, loggedIn: false, userId: ''), isFalse);
    expect(aiRolloutEligible(aiEnabled: true, rolloutPercent: 0, loggedIn: true, userId: 'a'), isFalse);
    expect(aiRolloutEligible(aiEnabled: true, rolloutPercent: 98, loggedIn: true, userId: 'a'), isTrue);
    expect(aiRolloutEligible(aiEnabled: true, rolloutPercent: 97, loggedIn: true, userId: 'a'), isFalse);
  });
}
