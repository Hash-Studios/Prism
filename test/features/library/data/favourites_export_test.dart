import 'dart:convert';
import 'dart:io';

import 'package:Prism/features/library/data/favourites_export.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../favourite_walls/support/fav_fixtures.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 3, 9, 8, 30);

  test('the JSON holds the count and one Firestore doc map per favourite', () {
    final String json = buildFavouritesExportJson([
      prismFav('a', author: 'Ada', category: 'Nature', createdAt: DateTime.utc(2025, 1, 3)),
      pexelsFav('b', author: 'Grace'),
      wallhavenFav('c'),
    ], now: now);

    final Map<String, Object?> decoded = jsonDecode(json) as Map<String, Object?>;
    expect(decoded['app'], 'Prism');
    expect(decoded['exportedAt'], '2026-03-09T08:30:00.000Z');
    expect(decoded['count'], 3);
    final List<Map<String, Object?>> items = (decoded['favourites']! as List<Object?>).cast<Map<String, Object?>>();
    expect(items.map((item) => item['id']), <String>['a', 'b', 'c']);
    expect(items.first['url'], 'https://example.com/a.jpg');
    expect(items.first['thumb'], 'https://example.com/a-thumb.jpg');
    expect(items.first['photographer'], 'Ada');
    expect(items.first['category'], 'Nature');
    expect(items.first['createdAt'], '2025-01-03T00:00:00.000Z');
    expect(items.first['favouritedAt'], isA<String>());
    expect(items.first['provider'], isNotEmpty);
  });

  test('an empty list still gives valid JSON', () {
    final Map<String, Object?> decoded =
        jsonDecode(buildFavouritesExportJson(const [], now: now)) as Map<String, Object?>;
    expect(decoded['count'], 0);
    expect(decoded['favourites'], isEmpty);
  });

  test('the file name carries the date', () {
    expect(favouritesExportFileName(now), 'prism-favourites-2026-03-09.json');
  });

  test('writeFavouritesExportFile saves the JSON in the given directory', () async {
    final Directory dir = Directory.systemTemp.createTempSync('favourites_export_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    final File file = await writeFavouritesExportFile([prismFav('a')], directory: dir, now: now);

    expect(file.path, '${dir.path}/prism-favourites-2026-03-09.json');
    expect((jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['count'], 1);
  });
}
