import 'dart:math';
import 'dart:typed_data';

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

  group('wallLookOf', () {
    Uint8List fill(int w, int h, int Function(int x, int y) v) {
      final Uint8List b = Uint8List(w * h * 4);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int i = (y * w + x) * 4;
          b[i] = b[i + 1] = b[i + 2] = v(x, y);
          b[i + 3] = 255;
        }
      }
      return b;
    }

    test('black is dark and minimal, white is light, mid grey has no tone', () {
      final black = wallLookOf(fill(8, 8, (_, _) => 0), 8, 8);
      expect(toneOfLook(black), QuizTone.dark);
      expect(densityOfLook(black), QuizDensity.minimal);
      expect(toneOfLook(wallLookOf(fill(8, 8, (_, _) => 255), 8, 8)), QuizTone.light);
      expect(toneOfLook(wallLookOf(fill(8, 8, (_, _) => 0x80), 8, 8)), isNull);
    });

    test('a checkerboard is busy and a smooth gradient is minimal', () {
      expect(densityOfLook(wallLookOf(fill(8, 8, (x, y) => (x + y).isEven ? 0 : 255), 8, 8)), QuizDensity.busy);
      expect(densityOfLook(wallLookOf(fill(64, 4, (x, _) => x * 4), 64, 4)), QuizDensity.minimal);
    });

    test('null look gives null tone and density', () {
      expect(toneOfLook(null), isNull);
      expect(densityOfLook(null), isNull);
    });
  });

  group('summarizeTaste with looks', () {
    const WallLook darkLook = WallLook(luma: 0.1, edges: 0.06);
    const WallLook lightLook = WallLook(luma: 0.9, edges: 0.06);

    List<QuizPick> picks() => <QuizPick>[
      for (int i = 0; i < 6; i++)
        _pickLeft(quizWall('p$i', colors: <String>['red', 'blue']), quizWall('q$i', colors: <String>['red', 'blue'])),
    ];

    test('dark looks give tone dark when tags and colours say nothing', () {
      final List<QuizPick> p = picks();
      expect(summarizeTaste(p).tone, isNull);
      final looks = <String, WallLook>{for (int i = 0; i < 4; i++) p[i].picked.key: darkLook};
      expect(summarizeTaste(p, looks: looks).tone, QuizTone.dark);
    });

    test('a light look beats a dark tag', () {
      final List<QuizPick> p = <QuizPick>[
        for (int i = 0; i < 6; i++) _pickLeft(quizWall('p$i', tags: <String>['dark']), quizWall('q$i')),
      ];
      expect(summarizeTaste(p).tone, QuizTone.dark);
      final looks = <String, WallLook>{for (final pick in p) pick.picked.key: lightLook};
      expect(summarizeTaste(p, looks: looks).tone, QuizTone.light);
    });

    test('an explicit density tag beats the look estimate', () {
      final List<QuizPick> p = <QuizPick>[
        for (int i = 0; i < 6; i++) _pickLeft(quizWall('p$i', tags: <String>['minimal']), quizWall('q$i')),
      ];
      final looks = <String, WallLook>{for (final pick in p) pick.picked.key: const WallLook(luma: 0.5, edges: 0.5)};
      expect(summarizeTaste(p, looks: looks).density, QuizDensity.minimal);
    });
  });

  test('a detailed photo at 0.07 edge contrast reads busy', () {
    expect(densityOfLook(const WallLook(luma: 0.4, edges: 0.07)), QuizDensity.busy);
  });
}
