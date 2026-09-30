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

  test('hidden markers remain after the 14-day fatigue window', () async {
    await store.hide('a', now);

    expect(store.recentShows(now.add(const Duration(days: 15))), <String, int>{'a': 99});
  });

  test('ordinary impressions never collide with the hidden marker', () async {
    for (int i = 0; i < 99; i++) {
      await store.recordShown(<String>['a'], now.add(Duration(minutes: i)));
    }

    expect(store.recentShows(now.add(const Duration(minutes: 99))), <String, int>{'a': 98});
    expect(store.recentShows(now.add(const Duration(days: 15))), isEmpty);
  });

  test('recording a hidden wall does not remove its hidden marker', () async {
    await store.hide('a', now);
    await store.recordShown(<String>['a'], now.add(const Duration(days: 15)));

    expect(store.recentShows(now.add(const Duration(days: 16))), <String, int>{'a': 99});
  });

  test('the 800-entry cap evicts the oldest hidden marker', () async {
    await store.hide('hidden', now);
    await store.recordShown(<String>[for (int i = 0; i < 800; i++) 'k$i'], now.add(const Duration(minutes: 1)));

    expect(store.recentShows(now.add(const Duration(minutes: 2))).containsKey('hidden'), isFalse);
  });

  test('ignores invalid negative impression counts in stored JSON', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = FeedImpressionStore(settings);
    await settings.set(
      'personalized_feed_impressions_v1',
      '{"invalid":[-1,${now.millisecondsSinceEpoch ~/ 60000}],'
          '"valid":[2,${now.millisecondsSinceEpoch ~/ 60000}]}',
    );

    expect(store.recentShows(now), <String, int>{'valid': 2});
  });

  test('ignores invalid timestamps without losing valid impressions', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = FeedImpressionStore(settings);
    await settings.set(
      'personalized_feed_impressions_v1',
      '{"invalid":[2,200000000000],"valid":[2,${now.millisecondsSinceEpoch ~/ 60000}]}',
    );

    expect(store.recentShows(now), <String, int>{'valid': 2});
  });

  test('rejects minute timestamps that overflow during millisecond conversion', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = FeedImpressionStore(settings);
    await settings.set(
      'personalized_feed_impressions_v1',
      '{"invalid":[99,576460752303423488],"valid":[2,${now.millisecondsSinceEpoch ~/ 60000}]}',
    );

    expect(store.recentShows(now), <String, int>{'valid': 2});
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
