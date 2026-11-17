import 'dart:io';

import 'package:Prism/core/personalization/ranking_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feed_replay.dart';

/// Floors for the shipped rules, about 1 point under the measured value (20 seeds, 8 sessions, 2 pages each).
/// A change that makes the feed worse for one of these users fails here. Raise a floor when a change earns it.
const Map<String, ({double hit, double coldHit, double maxPerCreator})> _floors =
    <String, ({double hit, double coldHit, double maxPerCreator})>{
      'amoled only': (hit: 0.50, coldHit: 0.72, maxPerCreator: 3.0),
      'anime + nature': (hit: 0.71, coldHit: 0.70, maxPerCreator: 3.0),
      'new user': (hit: 0.44, coldHit: 0.07, maxPerCreator: 3.2),
      'less like cars': (hit: 0.77, coldHit: 0.99, maxPerCreator: 3.1),
      'stale interest': (hit: 0.45, coldHit: 0.38, maxPerCreator: 3.3),
      'grid saver': (hit: 0.44, coldHit: 0.07, maxPerCreator: 2.9),
      'broad taste': (hit: 0.81, coldHit: 0.88, maxPerCreator: 4.5),
    };

void main() {
  final ReplayRanker shipped = rulesReplayRanker('x2026', RankingRules.x2026);

  for (final ReplayPersona persona in replayPersonas) {
    test('${persona.name}: the X 2026 rules keep the feed at or above its floors', () async {
      final ReplayMetrics m = await replay(persona, shipped);
      final floor = _floors[persona.name]!;
      expect(m.hitRate, greaterThanOrEqualTo(floor.hit), reason: 'hit@24');
      expect(m.coldStartHit, greaterThanOrEqualTo(floor.coldHit), reason: 'cold start hit');
      expect(m.maxPerCreator, lessThanOrEqualTo(floor.maxPerCreator), reason: 'walls per creator in a page');
      expect(m.repeatRate, lessThanOrEqualTo(0.05), reason: 'page 1 repeats from the last session');
      expect(m.dislikedRate, lessThanOrEqualTo(0.005), reason: 'less-liked category comes back');
      expect(m.hiddenBack, 0, reason: 'hidden walls come back');
      expect(m.variantDupes, 0, reason: 'light and dark versions in one page');
    });
  }

  test('prints the master vs X 2026 table', () async {
    final StringBuffer table = StringBuffer(ReplayMetrics.header);
    for (final ReplayPersona persona in replayPersonas) {
      table
        ..write('\n${(await replay(persona, legacyReplayRanker)).row('master')}')
        ..write('\n${(await replay(persona, shipped)).row('x2026')}');
    }
    // ignore: avoid_print
    print(table);
  }, skip: Platform.environment['REPLAY_TABLE'] == null ? 'Set REPLAY_TABLE=1 to print the table' : false);
}
