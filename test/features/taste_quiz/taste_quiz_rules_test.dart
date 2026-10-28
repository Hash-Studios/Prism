import 'dart:math';

import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taste_quiz_fixtures.dart';

QuizPick _pickLeft(QuizWall left, QuizWall right) => QuizPick(
  round: QuizRound(left: left, right: right),
  side: QuizSide.left,
);

List<QuizWall> _interestWalls(int count) => <QuizWall>[
  for (int i = 0; i < count; i++)
    if (i.isEven)
      quizWall('i$i', tags: <String>['dark', 'minimal'], colors: <String>['black'])
    else
      quizWall('i$i', tags: <String>['bright', 'city'], colors: <String>['yellow']),
];

List<QuizWall> _wildWalls(int count) => <QuizWall>[
  for (int i = 0; i < count; i++)
    quizWall('w$i', category: 'Abstract', wildCard: true, tags: <String>['bright', 'city'], colors: <String>['yellow']),
];

void main() {
  group('quizWallOf', () {
    test('tags dark and minimal give tone dark and density minimal', () {
      final QuizWall wall = quizWall('a', tags: <String>['dark', 'minimal']);

      expect(wall.tone, QuizTone.dark);
      expect(wall.density, QuizDensity.minimal);
    });

    test('no tags and one colour give tone light, mood mono and density minimal', () {
      final QuizWall wall = quizWall('a', colors: <String>['white']);

      expect(wall.tone, QuizTone.light);
      expect(wall.mood, QuizMood.mono);
      expect(wall.density, QuizDensity.minimal);
    });

    test('no tags and several colours give tone null, mood warm and density null', () {
      final QuizWall wall = quizWall('a', colors: <String>['red', 'blue', 'green']);

      expect(wall.tone, isNull);
      expect(wall.mood, QuizMood.warm);
      expect(wall.density, isNull);
    });

    test('terms include the lowercased category', () {
      final QuizWall wall = quizWall('a', category: 'Abstract', tags: <String>['Neon']);

      expect(wall.terms, containsAll(<String>['abstract', 'neon']));
    });
  });

  group('planTasteQuiz', () {
    test('six rounds with wild cards at index 2 and 4, no wall shown twice, interest rounds contrast tone', () {
      final List<QuizWall> walls = <QuizWall>[..._interestWalls(12), ..._wildWalls(6)];

      final TasteQuizPlan? plan = planTasteQuiz(walls, Random(1));

      expect(plan, isNotNull);
      expect(plan!.rounds.length, 6);
      for (int i = 0; i < plan.rounds.length; i++) {
        expect(plan.rounds[i].wildCard, i == 2 || i == 4, reason: 'round $i');
      }
      final Set<String> shown = <String>{};
      for (final QuizRound round in plan.rounds) {
        shown
          ..add(round.left.key)
          ..add(round.right.key);
      }
      expect(shown.length, 12);
      for (final QuizRound round in plan.rounds.where((round) => !round.wildCard)) {
        expect(round.left.tone, isNot(round.right.tone));
      }
    });

    test('twelve interest walls and no wild walls give six rounds with no wild card', () {
      final TasteQuizPlan? plan = planTasteQuiz(_interestWalls(12), Random(1));

      expect(plan, isNotNull);
      expect(plan!.rounds.length, 6);
      expect(plan.rounds.any((round) => round.wildCard), isFalse);
    });

    test('ten interest walls and two wild walls give one wild card round at index 2', () {
      final TasteQuizPlan? plan = planTasteQuiz(<QuizWall>[..._interestWalls(10), ..._wildWalls(2)], Random(1));

      expect(plan, isNotNull);
      expect(plan!.rounds.length, 6);
      expect(plan.rounds.where((round) => round.wildCard).length, 1);
      expect(plan.rounds[2].wildCard, isTrue);
    });

    test('nine interest walls and no wild walls return null', () {
      expect(planTasteQuiz(_interestWalls(9), Random(1)), isNull);
    });

    test('ten interest walls and no wild walls return null', () {
      expect(planTasteQuiz(_interestWalls(10), Random(1)), isNull);
    });

    test('twelve walls with one duplicate id, eleven distinct, return null', () {
      final List<QuizWall> walls = <QuizWall>[
        for (int i = 0; i < 12; i++)
          quizWall('i${min(i, 10)}', tags: <String>['dark', 'minimal'], colors: <String>['black']),
      ];

      expect(planTasteQuiz(walls, Random(1)), isNull);
    });

    test('pool holds the walls left over and no pool wall appears in a round', () {
      final List<QuizWall> walls = <QuizWall>[..._interestWalls(14), ..._wildWalls(4)];

      final TasteQuizPlan? plan = planTasteQuiz(walls, Random(1));

      expect(plan, isNotNull);
      expect(plan!.pool.length, 6);
      final Set<String> shown = <String>{
        for (final QuizRound round in plan.rounds) ...<String>[round.left.key, round.right.key],
      };
      expect(plan.pool.where((wall) => shown.contains(wall.key)), isEmpty);
    });
  });

  group('quizContrast', () {
    test('dark minimal mono against light busy warm in another category adds 3 + 2 + 2 + 1', () {
      final QuizWall dark = quizWall('a', tags: <String>['dark', 'minimal'], colors: <String>['black']);
      final QuizWall light = quizWall(
        'b',
        category: 'Abstract',
        tags: <String>['bright', 'city'],
        colors: <String>['yellow'],
      );

      expect(quizContrast(dark, light), 3 + 2 + 2 + 1);
      expect(quizContrast(dark, dark), 0);
    });
  });

  group('summarizeTaste', () {
    test('empty picks give an empty summary', () {
      final TasteSummary summary = summarizeTaste(const <QuizPick>[]);

      expect(summary.isEmpty, isTrue);
      expect(summary.tone, isNull);
      expect(summary.density, isNull);
      expect(summary.tag, isNull);
    });

    test('one shared tag on every picked wall gives that tag and no tone or density', () {
      final List<QuizPick> picks = <QuizPick>[
        for (int i = 0; i < 6; i++)
          _pickLeft(quizWall('p$i', tags: <String>['neon']), quizWall('q$i', tags: <String>['beach'])),
      ];

      final TasteSummary summary = summarizeTaste(picks);

      expect(summary.tone, isNull);
      expect(summary.density, isNull);
      expect(summary.tag, 'neon');
    });

    test('many shared traits give tone dark, density minimal and tag neon', () {
      final TasteQuizPlan plan = quizPlan();
      final List<QuizPick> picks = <QuizPick>[
        for (final QuizRound round in plan.rounds) QuizPick(round: round, side: QuizSide.left),
      ];

      final TasteSummary summary = summarizeTaste(picks);

      expect(summary.tone, QuizTone.dark);
      expect(summary.density, QuizDensity.minimal);
      expect(summary.tag, 'neon');
    });

    test('picks that disagree give no tone and no tag', () {
      final List<QuizPick> picks = <QuizPick>[
        for (int i = 0; i < 6; i++)
          _pickLeft(
            quizWall('p$i', tags: <String>[if (i < 3) 'dark' else 'bright', 't$i']),
            quizWall('q$i', tags: <String>['beach']),
          ),
      ];

      final TasteSummary summary = summarizeTaste(picks);

      expect(summary.tone, isNull);
      expect(summary.tag, isNull);
    });

    test('a tag that appears on only one pick is not used', () {
      final List<QuizPick> picks = <QuizPick>[
        for (int i = 0; i < 6; i++)
          _pickLeft(
            quizWall('p$i', tags: <String>[if (i == 0) 'lonely' else 'p$i']),
            quizWall('q$i', tags: <String>['beach']),
          ),
      ];

      expect(summarizeTaste(picks).tag, isNull);
    });

    test('a tag that appears equally on picked and passed walls is not used', () {
      final List<QuizPick> picks = <QuizPick>[
        for (int i = 0; i < 6; i++)
          _pickLeft(
            quizWall('p$i', tags: <String>[if (i < 3) 'shared' else 'p$i']),
            quizWall('q$i', tags: <String>[if (i >= 3) 'shared' else 'q$i']),
          ),
      ];

      expect(summarizeTaste(picks).tag, isNull);
    });
  });
}
