import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'detail_replay.dart';
import 'feed_replay.dart';

/// Floors for the personal order, about 1 point under the measured value (20 seeds, 20 opens each).
const Map<String, ({double liked, double overlap})> _floors = <String, ({double liked, double overlap})>{
  'amoled only': (liked: 0.69, overlap: 0.57),
  'anime + nature': (liked: 0.69, overlap: 0.58),
  'new user': (liked: 0.69, overlap: 0.56),
  'less like cars': (liked: 0.69, overlap: 0.59),
  'stale interest': (liked: 0.69, overlap: 0.56),
  'grid saver': (liked: 0.69, overlap: 0.58),
  'broad taste': (liked: 0.69, overlap: 0.59),
  'anime, colorful only': (liked: 0.27, overlap: 0.57),
  'city, not one creator': (liked: 0.62, overlap: 0.53),
};

void main() {
  for (final persona in detailPersonas) {
    test('${persona.name}: the walls under an open wallpaper stay related and lean to the taste', () async {
      final DetailMetrics m = await replayDetail(persona, personal: true);
      final floor = _floors[persona.name]!;
      expect(m.hitRate, greaterThanOrEqualTo(floor.liked), reason: 'liked walls in the next 12');
      expect(m.related, greaterThanOrEqualTo(floor.overlap), reason: 'tag overlap with the open wall');
      expect(m.hiddenShown, 0, reason: 'hidden walls');
      expect(m.pairs, 0, reason: 'light and dark versions in the next 12');
    });
  }

  test('the city user sees under a quarter of the disliked creator walls the query order shows', () async {
    final ReplayPersona persona = detailPersonas.singleWhere((p) => p.name == 'city, not one creator');
    final DetailMetrics before = await replayDetail(persona, personal: false);
    final DetailMetrics after = await replayDetail(persona, personal: true);
    expect(after.dislikedCreatorShown, lessThan(before.dislikedCreatorShown / 4));
  });

  test('prints the wallpaper-screen table', () async {
    final StringBuffer table = StringBuffer(DetailMetrics.header);
    for (final persona in detailPersonas) {
      table
        ..write('\n${(await replayDetail(persona, personal: false)).row('query order')}')
        ..write('\n${(await replayDetail(persona, personal: true)).row('personal')}');
    }
    // ignore: avoid_print
    print(table);
  }, skip: Platform.environment['REPLAY_TABLE'] == null ? 'Set REPLAY_TABLE=1 to print the table' : false);
}
