import 'dart:convert';

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

  test('a hidden wall survives 800 newer impressions', () async {
    await store.hide('hidden', now);
    await store.recordShown(<String>[for (int i = 0; i < 800; i++) 'k$i'], now.add(const Duration(minutes: 1)));

    expect(store.recentShows(now.add(const Duration(minutes: 2)))['hidden'], 99);
  });

  test('legacy hides survive upgrade, re-recording and impression eviction', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = FeedImpressionStore(settings);
    await settings.set(
      'personalized_feed_impressions_v1',
      '{"hidden":[99,${now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 60000}]}',
    );

    expect(store.recentShows(now), <String, int>{'hidden': 99});
    await store.recordShown(<String>['hidden'], now);
    await store.recordShown(<String>[for (int i = 0; i < 800; i++) 'k$i'], now.add(const Duration(minutes: 1)));
    store = FeedImpressionStore(settings);

    expect(store.recentShows(now.add(const Duration(days: 15))), <String, int>{'hidden': 99});
  });

  test('the hidden cap evicts the oldest hide, not a recently re-hidden legacy wall', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = FeedImpressionStore(settings);
    await settings.set('personalized_feed_hidden_v1', jsonEncode(<String>[for (int i = 0; i < 2000; i++) 'k$i']));
    await settings.set('personalized_feed_impressions_v1', '{"k0":[99,${now.millisecondsSinceEpoch ~/ 60000}]}');

    await store.hide('k0', now);
    await store.recordShown(<String>['k0'], now);
    await store.hide('new', now);

    final Map<String, int> shows = store.recentShows(now);
    expect(shows, hasLength(2000));
    expect(shows['k0'], 99);
    expect(shows.containsKey('k1'), isFalse);
    expect(shows['new'], 99);
  });

  test('malformed hidden data keeps legacy hides and valid list entries', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = FeedImpressionStore(settings);
    await settings.set('personalized_feed_impressions_v1', '{"legacy":[99,${now.millisecondsSinceEpoch ~/ 60000}]}');
    for (final String raw in <String>['not json', '{}']) {
      await settings.set('personalized_feed_hidden_v1', raw);
      expect(store.recentShows(now.add(const Duration(days: 15))), <String, int>{'legacy': 99});
    }
    await settings.set('personalized_feed_hidden_v1', '["hidden",null,7,"hidden"]');
    await store.recordShown(<String>['shown'], now);

    expect(store.recentShows(now), <String, int>{'shown': 1, 'legacy': 99, 'hidden': 99});
  });

  test('a new hide does not resurrect a legacy marker evicted by the hidden cap', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = FeedImpressionStore(settings);
    await settings.set('personalized_feed_hidden_v1', jsonEncode(<String>[for (int i = 0; i < 2000; i++) 'k$i']));
    await settings.set('personalized_feed_impressions_v1', '{"legacy":[99,${now.millisecondsSinceEpoch ~/ 60000}]}');

    await store.hide('new', now);

    final Map<String, int> shows = store.recentShows(now);
    expect(shows, hasLength(2000));
    expect(shows.containsKey('legacy'), isFalse);
    expect(shows.containsKey('k0'), isFalse);
    expect(shows['new'], 99);
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
