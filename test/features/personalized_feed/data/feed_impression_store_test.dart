import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 6);
  late FeedImpressionStore store;

  setUp(() {
    store = FeedImpressionStore(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  test('recording twice counts two shows', () async {
    await store.recordShown(<String>['a'], now);
    await store.recordShown(<String>['a'], now.add(const Duration(minutes: 1)));

    expect(store.recentShows(now.add(const Duration(minutes: 2))), <String, int>{'a': 2});
  });

  test('shows older than 14 days are dropped', () async {
    await store.recordShown(<String>['a'], now);

    expect(store.recentShows(now.add(const Duration(days: 15))), isEmpty);
  });

  test('hide sinks a key to 99 shows', () async {
    await store.recordShown(<String>['a'], now);
    await store.hide('a', now);

    expect(store.recentShows(now), <String, int>{'a': 99});
  });

  test('keeps the newest 800 keys', () async {
    for (int i = 0; i < 810; i++) {
      await store.recordShown(<String>['k$i'], now.add(Duration(minutes: i)));
    }

    final Map<String, int> shows = store.recentShows(now.add(const Duration(minutes: 810)));
    expect(shows, hasLength(800));
    expect(shows.containsKey('k9'), isFalse);
    expect(shows.containsKey('k10'), isTrue);
    expect(shows.containsKey('k809'), isTrue);
  });
}
