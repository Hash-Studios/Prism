import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_user_fixture.dart';

void main() {
  test('returns 0/4 when only defaults exist', () {
    final status = ProfileCompletenessEvaluator.evaluate(profileUser(), defaultProfilePhotoUrl: defaultProfilePhotoUrl);

    expect(status.completedSteps, 0);
    expect(status.percent, 0);
    expect(status.progress, 0);
    expect(status.missingSteps.length, 4);
  });

  test('default profile photo does not count as completed photo', () {
    final status = ProfileCompletenessEvaluator.evaluate(
      profileUser(
        username: 'creator_01',
        bio: 'hello world',
        links: const <String, String>{'instagram': 'https://instagram.com/creator'},
      ),
      defaultProfilePhotoUrl: defaultProfilePhotoUrl,
    );

    expect(status.completedSteps, 3);
    expect(status.percent, 75);
    expect(status.missingSteps, contains(ProfileCompletenessStep.photo));
  });

  test('transitions 25, 50, 75, and 100 percent as fields are completed', () {
    final status25 = ProfileCompletenessEvaluator.evaluate(
      profileUser(profilePhoto: 'https://example.com/photo.png'),
      defaultProfilePhotoUrl: defaultProfilePhotoUrl,
    );
    final status50 = ProfileCompletenessEvaluator.evaluate(
      profileUser(profilePhoto: 'https://example.com/photo.png', username: 'creator_01'),
      defaultProfilePhotoUrl: defaultProfilePhotoUrl,
    );
    final status75 = ProfileCompletenessEvaluator.evaluate(
      profileUser(profilePhoto: 'https://example.com/photo.png', username: 'creator_01', bio: 'hello world'),
      defaultProfilePhotoUrl: defaultProfilePhotoUrl,
    );
    final status100 = ProfileCompletenessEvaluator.evaluate(
      profileUser(
        profilePhoto: 'https://example.com/photo.png',
        username: 'creator_01',
        bio: 'hello world',
        links: const <String, String>{'github': 'https://github.com/creator'},
      ),
      defaultProfilePhotoUrl: defaultProfilePhotoUrl,
    );

    expect(status25.percent, 25);
    expect(status50.percent, 50);
    expect(status75.percent, 75);
    expect(status100.percent, 100);
    expect(status100.isComplete, isTrue);
  });

  test('any non-empty social link value satisfies social link step', () {
    final status = ProfileCompletenessEvaluator.evaluate(
      profileUser(
        profilePhoto: 'https://example.com/photo.png',
        username: 'creator_01',
        bio: 'hello world',
        links: const <String, String>{'custom link': '   https://site.example/u1  '},
      ),
      defaultProfilePhotoUrl: defaultProfilePhotoUrl,
    );

    expect(status.percent, 100);
    expect(status.missingSteps, isEmpty);
  });
}
