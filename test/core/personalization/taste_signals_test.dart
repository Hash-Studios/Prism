import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  late TasteSignalStore store;

  setUp(() {
    store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  test('record then read round-trips action, terms and creator', () async {
    final DateTime at = DateTime.utc(2026, 1, 2, 3, 4, 5);
    await store.record(TasteSignal(action: TasteAction.favourite, at: at, terms: const ['nature'], creator: 'a@b.c'));

    final List<TasteSignal> read = store.read();
    expect(read, hasLength(1));
    expect(read.first.action, TasteAction.favourite);
    expect(read.first.terms, ['nature']);
    expect(read.first.creator, 'a@b.c');
    expect(read.first.at, at);
  });

  test('keeps the newest 300 signals', () async {
    final DateTime start = DateTime.utc(2026);
    await store.recordAll(<TasteSignal>[
      for (int i = 0; i < 310; i++)
        TasteSignal(
          action: TasteAction.open,
          at: start.add(Duration(minutes: i)),
          terms: <String>['t$i'],
        ),
    ]);

    final List<TasteSignal> read = store.read();
    expect(read, hasLength(300));
    expect(read.first.terms, ['t10']);
    expect(read.last.terms, ['t309']);
  });

  test('drops malformed stored terms without discarding valid signals', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final TasteSignalStore malformedStore = TasteSignalStore(settings);
    await settings.set(
      'personalized_taste_signals_v1',
      jsonEncode(<Map<String, Object?>>[
        <String, Object?>{
          'a': 'open',
          't': '2026-01-01T00:00:00.000Z',
          'k': <Object?>['', null, 42, ' general '],
        },
        <String, Object?>{
          'a': 'favourite',
          't': '2026-01-02T00:00:00.000Z',
          'k': <Object?>[' Nature ', 'nature', true],
        },
      ]),
    );

    final List<TasteSignal> signals = malformedStore.read();
    expect(signals, hasLength(1));
    expect(signals.single.terms, <String>['nature']);
  });

  test('tasteTermsOf lowercases, de-duplicates and drops noise terms', () {
    final WallpaperCore core = _core(category: 'Community');
    final List<String> terms = tasteTermsOf(
      core,
      tags: <String>['Nature', 'nature', ' Sky ', 'General', ''],
      collections: <String>['SKY'],
    );
    expect(terms, ['nature', 'sky']);
  });

  test('a tagless external wall learns the search terms the feed found it with', () {
    const WallpaperCore core = WallpaperCore(
      id: 'wh1',
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://w.wallhaven.cc/full/ab/wallhaven-ab.jpg',
      thumbnailUrl: 't',
      category: 'general',
    );
    expect(TasteSignal.forWallpaper(TasteAction.open, core).terms, isEmpty);

    rememberFeedTerms('https://w.wallhaven.cc/full/ab/wallhaven-ab.jpg', <String>['space']);

    expect(TasteSignal.forWallpaper(TasteAction.open, core).terms, <String>['space']);
  });
}

WallpaperCore _core({String? category}) =>
    WallpaperCore(id: 'w1', source: WallpaperSource.prism, fullUrl: 'f', thumbnailUrl: 't', category: category);
