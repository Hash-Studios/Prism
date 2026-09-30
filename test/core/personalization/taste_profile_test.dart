import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 6);

  TasteProfile build({
    Iterable<String> interests = const <String>[],
    Iterable<String> following = const <String>[],
    List<TasteSignal> signals = const <TasteSignal>[],
  }) => TasteProfile.build(interests: interests, following: following, signals: signals, now: now);

  group('FeedMix.parse', () {
    test('maps known values and falls back to balanced', () {
      expect(FeedMix.parse('creators'), FeedMix.familiar);
      expect(FeedMix.parse('discovery'), FeedMix.adventurous);
      expect(FeedMix.parse('adventurous'), FeedMix.adventurous);
      expect(FeedMix.parse(null), FeedMix.balanced);
      expect(FeedMix.parse('x'), FeedMix.balanced);
    });
  });

  group('TasteProfile', () {
    test('interest matches item terms that contain it', () {
      final TasteProfile profile = build(interests: <String>['Space']);

      expect(profile.termAffinity(<String>['deep space']), 1.0);
      expect(profile.termAffinity(<String>['forest']), 0);
    });

    test('recent set signal outweighs a 60 day old one', () {
      final TasteProfile profile = build(
        signals: <TasteSignal>[
          TasteSignal(action: TasteAction.set, at: now, terms: const <String>['a']),
          TasteSignal(action: TasteAction.set, at: now.subtract(const Duration(days: 60)), terms: const <String>['b']),
        ],
      );

      expect(profile.strengthOf('a'), 1.0);
      expect(profile.strengthOf('b'), closeTo(0.25, 0.01));
    });

    test('lessLikeThis turns a term negative', () {
      final TasteProfile profile = build(
        interests: <String>['space'],
        signals: <TasteSignal>[
          TasteSignal(action: TasteAction.lessLikeThis, at: now, terms: const <String>['space']),
        ],
      );

      expect(profile.termAffinity(<String>['space']), lessThan(0));
      expect(profile.topTerms(5), isNot(contains('space')));
    });

    test('followed creator scores 1 and unknown creator 0', () {
      final TasteProfile profile = build(following: <String>['a@b.c']);

      expect(profile.creatorAffinity('a@b.c'), 1.0);
      expect(profile.creatorAffinity('z@b.c'), 0);
    });
  });
}
