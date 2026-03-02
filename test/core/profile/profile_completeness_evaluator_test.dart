import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

const String _defaultPhotoUrl = 'https://example.com/default.png';

PrismUsersV2 _user({
  String profilePhoto = _defaultPhotoUrl,
  String username = '',
  String bio = '',
  Map<dynamic, dynamic>? links,
}) {
  return PrismUsersV2(
    username: username,
    email: 'user@example.com',
    id: 'u1',
    createdAt: DateTime.now().toUtc().toIso8601String(),
    premium: false,
    lastLoginAt: DateTime.now().toUtc().toIso8601String(),
    links: links ?? <String, dynamic>{},
    followers: <dynamic>[],
    following: <dynamic>[],
    profilePhoto: profilePhoto,
    bio: bio,
    loggedIn: true,
    badges: <Badge>[],
    subPrisms: <dynamic>[],
    coins: 0,
    transactions: <PrismTransaction>[],
    name: '',
    coverPhoto: '',
  );
}

void main() {
  test('returns 0/4 when only defaults exist', () {
    final status = ProfileCompletenessEvaluator.evaluate(_user(), defaultProfilePhotoUrl: _defaultPhotoUrl);

    expect(status.completedSteps, 0);
    expect(status.percent, 0);
    expect(status.progress, 0);
    expect(status.missingSteps.length, 4);
  });

  test('default profile photo does not count as completed photo', () {
    final status = ProfileCompletenessEvaluator.evaluate(
      _user(
        username: 'creator_01',
        bio: 'hello world',
        links: <String, dynamic>{'instagram': 'https://instagram.com/creator'},
      ),
      defaultProfilePhotoUrl: _defaultPhotoUrl,
    );

    expect(status.completedSteps, 3);
    expect(status.percent, 75);
    expect(status.missingSteps, contains(ProfileCompletenessStep.photo));
  });

  test('transitions 25, 50, 75, and 100 percent as fields are completed', () {
    final status25 = ProfileCompletenessEvaluator.evaluate(
      _user(profilePhoto: 'https://example.com/photo.png'),
      defaultProfilePhotoUrl: _defaultPhotoUrl,
    );
    final status50 = ProfileCompletenessEvaluator.evaluate(
      _user(profilePhoto: 'https://example.com/photo.png', username: 'creator_01'),
      defaultProfilePhotoUrl: _defaultPhotoUrl,
    );
    final status75 = ProfileCompletenessEvaluator.evaluate(
      _user(profilePhoto: 'https://example.com/photo.png', username: 'creator_01', bio: 'hello world'),
      defaultProfilePhotoUrl: _defaultPhotoUrl,
    );
    final status100 = ProfileCompletenessEvaluator.evaluate(
      _user(
        profilePhoto: 'https://example.com/photo.png',
        username: 'creator_01',
        bio: 'hello world',
        links: <String, dynamic>{'github': 'https://github.com/creator'},
      ),
      defaultProfilePhotoUrl: _defaultPhotoUrl,
    );

    expect(status25.percent, 25);
    expect(status50.percent, 50);
    expect(status75.percent, 75);
    expect(status100.percent, 100);
    expect(status100.isComplete, isTrue);
  });

  test('any non-empty social link value satisfies social link step', () {
    final status = ProfileCompletenessEvaluator.evaluate(
      _user(
        profilePhoto: 'https://example.com/photo.png',
        username: 'creator_01',
        bio: 'hello world',
        links: <String, dynamic>{'custom link': '   https://site.example/u1  '},
      ),
      defaultProfilePhotoUrl: _defaultPhotoUrl,
    );

    expect(status.percent, 100);
    expect(status.missingSteps, isEmpty);
  });
}
