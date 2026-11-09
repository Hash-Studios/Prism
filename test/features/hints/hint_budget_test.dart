import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 9, 12);

  test('refuses sessions 1 and 2, allows session 3 with no history', () {
    expect(HintBudget.allows(now: now, session: 1, shownAt: const <DateTime>[]), isFalse);
    expect(HintBudget.allows(now: now, session: 2, shownAt: const <DateTime>[]), isFalse);
    expect(HintBudget.allows(now: now, session: 3, shownAt: const <DateTime>[]), isTrue);
  });

  test('refuses a hint shown 23 hours ago and allows one shown 25 hours ago', () {
    expect(
      HintBudget.allows(now: now, session: 3, shownAt: <DateTime>[now.subtract(const Duration(hours: 23))]),
      isFalse,
    );
    expect(
      HintBudget.allows(now: now, session: 3, shownAt: <DateTime>[now.subtract(const Duration(hours: 25))]),
      isTrue,
    );
  });

  test('refuses a fourth hint in 7 days and allows it when one of the three is 8 days old', () {
    expect(
      HintBudget.allows(
        now: now,
        session: 3,
        shownAt: <DateTime>[
          now.subtract(const Duration(days: 2)),
          now.subtract(const Duration(days: 4)),
          now.subtract(const Duration(days: 6)),
        ],
      ),
      isFalse,
    );
    expect(
      HintBudget.allows(
        now: now,
        session: 3,
        shownAt: <DateTime>[
          now.subtract(const Duration(days: 2)),
          now.subtract(const Duration(days: 4)),
          now.subtract(const Duration(days: 8)),
        ],
      ),
      isTrue,
    );
  });

  test('refuses 9 minutes after a prompt and allows 11 minutes after', () {
    expect(
      HintBudget.allows(
        now: now,
        session: 3,
        shownAt: const <DateTime>[],
        lastPromptAt: now.subtract(const Duration(minutes: 9)),
      ),
      isFalse,
    );
    expect(
      HintBudget.allows(
        now: now,
        session: 3,
        shownAt: const <DateTime>[],
        lastPromptAt: now.subtract(const Duration(minutes: 11)),
      ),
      isTrue,
    );
  });
  test('clock rollback blocks hints until timestamps catch up', () {
    expect(HintBudget.allows(now: now, session: 3, shownAt: <DateTime>[now.add(const Duration(hours: 1))]), isFalse);
    expect(
      HintBudget.allows(
        now: now,
        session: 3,
        shownAt: const <DateTime>[],
        lastPromptAt: now.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
  });

  test('exact daily and prompt cooldown boundaries allow hints', () {
    expect(
      HintBudget.allows(
        now: now,
        session: 3,
        shownAt: <DateTime>[now.subtract(const Duration(days: 1))],
        lastPromptAt: now.subtract(const Duration(minutes: 10)),
      ),
      isTrue,
    );
  });
}
