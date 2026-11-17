import 'dart:math';

import 'package:Prism/core/personalization/ranking_rules.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
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
    test('legacy profile ignores every new action in both terms and creators', () {
      final TasteProfile profile = build(
        interests: const <String>[' Space '],
        following: const <String>[' CREATOR '],
        signals: <TasteSignal>[
          TasteSignal(action: TasteAction.set, at: now, terms: const <String>['space'], creator: 'creator'),
          TasteSignal(
            action: TasteAction.lessLikeThis,
            at: now.subtract(const Duration(days: 30)),
            terms: const <String>['cars'],
            creator: 'other',
          ),
          for (final TasteAction action in <TasteAction>[
            TasteAction.share,
            TasteAction.folderAdd,
            TasteAction.scrolledPast,
          ])
            TasteSignal(action: action, at: now, terms: const <String>['new'], creator: 'new'),
        ],
      );

      expect(profile.terms, <String, double>{'space': 10, 'cars': -4});
      expect(profile.creators, <String, double>{'creator': 12, 'other': -4});
      expect(profile.hardNegatives, isFalse);
    });

    test('each new action halves term and creator weight every 30 days', () {
      for (final MapEntry<TasteAction, double> entry in TasteProfile.newActionWeights.entries) {
        for (final int days in <int>[0, 30, 60]) {
          final TasteProfile profile = TasteProfile.build(
            interests: const <String>[],
            following: const <String>[],
            signals: <TasteSignal>[
              TasteSignal(
                action: entry.key,
                at: now.subtract(Duration(days: days)),
                terms: const <String>['space'],
                creator: 'creator',
              ),
            ],
            now: now,
            rules: RankingRules.x2026,
          );
          final double expected = entry.value * pow(0.5, days / 30);
          expect(profile.terms['space'], expected, reason: '${entry.key.name}, $days days');
          expect(profile.creators['creator'], expected, reason: '${entry.key.name}, $days days');
        }
      }
    });

    test('cached matches sum in old term order with exactly the same doubles', () {
      final Map<String, double> terms = <String, double>{
        'strongest': 1e16,
        'space': 1e16,
        'ocean': 1,
        'forest': -1e16,
        'city': 0.1,
        'deep': -0.3,
      };
      final TasteProfile profile = TasteProfile(terms: terms, creators: <String, double>{});
      final List<List<String>> inputs = <List<String>>[
        <String>['forest', 'space', 'ocean', 'city', 'deep space'],
        <String>['deep space', 'city', 'ocean', 'space', 'forest'],
        <String>['ocean', 'ocean', 'city'],
        <String>['unknown'],
        <String>[],
      ];
      for (int pass = 0; pass < 2; pass++) {
        for (final List<String> input in inputs) {
          final double scale = terms.values.fold(1, max);
          double oldSum = 0;
          for (final MapEntry<String, double> entry in terms.entries) {
            if (input.any((term) => term.contains(entry.key))) {
              oldSum += entry.value / scale;
            }
          }
          expect(profile.termAffinity(input), oldSum.clamp(-2, 2).toDouble());
        }
      }
    });

    test('hard negatives leave all positive term and creator affinities unchanged', () {
      final List<TasteSignal> signals = <TasteSignal>[
        for (int i = 0; i < 40; i++)
          TasteSignal(action: TasteAction.set, at: now, terms: const <String>['space'], creator: 'creator'),
        TasteSignal(action: TasteAction.favourite, at: now, terms: const <String>['ocean'], creator: 'other'),
        TasteSignal(action: TasteAction.lessLikeThis, at: now, terms: const <String>['cars'], creator: 'disliked'),
      ];
      TasteProfile profile(RankingRules rules) => TasteProfile.build(
        interests: const <String>[],
        following: const <String>[],
        signals: signals,
        now: now,
        rules: rules,
      );
      final TasteProfile legacy = profile(RankingRules.legacy);
      final TasteProfile hard = profile(const RankingRules(hardNegatives: true));
      expect(hard.terms, legacy.terms);
      expect(hard.creators, legacy.creators);
      expect(
        hard.termAffinity(const <String>['space', 'ocean']),
        legacy.termAffinity(const <String>['space', 'ocean']),
      );
      expect(hard.creatorAffinity('creator'), legacy.creatorAffinity('creator'));
      expect(hard.creatorAffinity('other'), legacy.creatorAffinity('other'));
      expect(hard.creatorAffinity('disliked'), lessThan(legacy.creatorAffinity('disliked')));
    });

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
