// The detail screen shows the Remix action when AiRemixSeed.of returns a seed for the wall, with the viewer built the
// way _remixSeedOf builds it. Pumping the full detail screen needs its bloc, router and Firebase setup, so this test
// checks that predicate directly. The screen also hides the action until the blocked creators have loaded.
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wall_remix_fixture.dart';

bool _showsRemix({
  required bool wallIsAi,
  bool isStudio = false,
  bool review = true,
  bool isPremiumWall = false,
  bool viewerIsPremium = false,
  bool blockedCreator = false,
  bool aiEnabled = true,
}) {
  final seed = AiRemixSeed.of(
    remixWall(
      isAi: wallIsAi,
      isStudio: isStudio,
      review: review,
      collections: isPremiumWall ? const <String>['space'] : null,
    ),
    viewer: WallViewer(
      isPremium: viewerIsPremium,
      premiumCollections: const <String>['space'],
      blockedCreators: KnownBlockedCreators(blockedCreator ? const <String>{'uid-asha'} : const <String>{}),
    ),
    aiEnabled: aiEnabled,
  );
  return seed != null;
}

void main() {
  test('shows the Remix action for a user AI wall', () {
    expect(_showsRemix(wallIsAi: true), isTrue);
  });

  test('shows the Remix action for a Studio wall', () {
    expect(_showsRemix(wallIsAi: true, isStudio: true), isTrue);
  });

  test('hides the Remix action for a wall that is not AI', () {
    expect(_showsRemix(wallIsAi: false), isFalse);
  });

  test('hides the Remix action for a premium-gated wall from a free viewer', () {
    expect(_showsRemix(wallIsAi: true, isPremiumWall: true), isFalse);
    expect(_showsRemix(wallIsAi: true, isPremiumWall: true, viewerIsPremium: true), isTrue);
  });

  test('hides the Remix action for a withdrawn wall', () {
    expect(_showsRemix(wallIsAi: true, review: false), isFalse);
  });

  test('hides the Remix action when the creator is blocked', () {
    expect(_showsRemix(wallIsAi: true, blockedCreator: true), isFalse);
  });

  test('hides the Remix action when AI is off', () {
    expect(_showsRemix(wallIsAi: true, aiEnabled: false), isFalse);
  });
}
