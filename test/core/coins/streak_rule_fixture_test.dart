import 'dart:io';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Android Streak widget runs the same cases in android/app/src/test/kotlin/com/hash/prism/StreakWidgetLogicTest.kt.
void main() {
  final List<List<String>> cases = File('test/fixtures/streak_rule_cases.csv')
      .readAsLinesSync()
      .skip(1)
      .where((String line) => line.trim().isNotEmpty)
      .map((String line) => line.split(','))
      .toList();

  test('the fixture has every case', () {
    expect(cases, hasLength(25));
  });

  for (final List<String> row in cases) {
    test('isStreakAlive(${row[0]}, ${row[1]}, ${row[2]}) is ${row[3]}, kept today ${row[4]}', () {
      final bool alive = isStreakAlive(row[0], row[1], int.parse(row[2]));
      expect(alive, row[3] == 'true');
      expect(alive && dayKeyGap(row[0], row[1]) == 0, row[4] == 'true');
    });
  }
}
