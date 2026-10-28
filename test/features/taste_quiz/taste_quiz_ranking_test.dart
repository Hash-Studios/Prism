import 'dart:math';

import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taste_quiz_fixtures.dart';

class _FixedRandom implements Random {
  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

void main() {
  group('ranker order after the quiz', () {
    final DateTime now = DateTime.utc(2026, 10, 28);
    final List<RankingCandidate> candidates = <RankingCandidate>[
      for (int i = 0; i < 3; i++)
        RankingCandidate(
          item: quizItem('dark$i', tags: <String>['dark', 'minimal']),
          pool: CandidatePool.taste,
        ),
      for (int i = 0; i < 3; i++)
        RankingCandidate(
          item: quizItem('light$i', tags: <String>['bright', 'city']),
          pool: CandidatePool.taste,
        ),
    ];
    const PersonalizedRankingService ranker = PersonalizedRankingService();

    List<String> rankWith(TasteProfile profile) => ranker
        .rank(
          candidates: candidates,
          profile: profile,
          recentShows: const <String, int>{},
          excludedKeys: const <String>{},
          mix: FeedMix.familiar,
          random: _FixedRandom(),
          now: now,
          limit: 6,
        )
        .items
        .map((item) => item.id)
        .toList();

    test('before the quiz the city interest puts the light walls first', () {
      final TasteProfile profile = TasteProfile.build(
        interests: <String>['city'],
        following: <String>[],
        signals: <TasteSignal>[],
        now: now,
      );

      expect(rankWith(profile).first, startsWith('light'));
    });

    test('after the quiz the dark walls rank first', () {
      final List<TasteSignal> signals = <TasteSignal>[
        for (final QuizPick pick in <QuizPick>[
          for (final QuizRound round in quizPlan().rounds) QuizPick(round: round, side: QuizSide.left),
        ])
          ...pick.signals(now),
      ];
      final TasteProfile profile = TasteProfile.build(
        interests: <String>['city'],
        following: <String>[],
        signals: signals,
        now: now,
      );

      expect(rankWith(profile).take(3), everyElement(startsWith('dark')));
    });

    test('a passed-over pick is weighted less than one eighth of a less-like-this', () {
      final double passedOver = TasteProfile.actionWeights[TasteAction.passedOver]!;
      final double lessLikeThis = TasteProfile.actionWeights[TasteAction.lessLikeThis]!;

      expect(passedOver, isNegative);
      expect(passedOver.abs(), lessThanOrEqualTo(lessLikeThis.abs() / 8));
    });

    test('one passed-over signal does not outweigh one favourite on the same term', () {
      final TasteProfile profile = TasteProfile.build(
        interests: <String>[],
        following: <String>[],
        signals: <TasteSignal>[
          TasteSignal(action: TasteAction.favourite, at: now, terms: <String>['neon']),
          TasteSignal(action: TasteAction.passedOver, at: now, terms: <String>['neon']),
        ],
        now: now,
      );

      expect(profile.terms['neon'], greaterThan(0));
    });

    test('a shared category stays positive when the picked wall has many terms', () {
      final QuizPick pick = QuizPick(
        round: QuizRound(
          left: quizWall('picked', tags: <String>['nature', for (int i = 0; i < 48; i++) 'picked$i']),
          right: quizWall('passed'),
        ),
        side: QuizSide.left,
      );
      final TasteProfile profile = TasteProfile.build(
        interests: <String>[],
        following: <String>[],
        signals: pick.signals(now),
        now: now,
      );

      expect(profile.terms['nature'], greaterThan(0));
    });
  });
}
