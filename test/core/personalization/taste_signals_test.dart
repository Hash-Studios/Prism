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
    clearRememberedFeedTerms();
    store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(clearRememberedFeedTerms);

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

  test('remembering another query for the same wall retains both terms', () {
    final WallpaperCore core = _core();
    rememberFeedTerms(' F ', <String>['Nature']);
    rememberFeedTerms('f', <String>[' Space ']);

    expect(TasteSignal.forWallpaper(TasteAction.lessLikeThis, core).terms, <String>['nature', 'space']);
  });

  test('clearing remembered terms isolates later signals', () {
    rememberFeedTerms('f', <String>['space']);
    expect(TasteSignal.forWallpaper(TasteAction.open, _core()).terms, <String>['space']);

    clearRememberedFeedTerms();

    expect(TasteSignal.forWallpaper(TasteAction.open, _core()).terms, isEmpty);
  });

  test('a wall without a full URL uses the ranker source and id fallback', () {
    const WallpaperCore core = WallpaperCore(
      id: ' AB ',
      source: WallpaperSource.wallhaven,
      fullUrl: ' ',
      thumbnailUrl: 't',
      category: 'general',
    );
    rememberFeedTerms('wallhaven:ab', <String>['space']);

    expect(TasteSignal.forWallpaper(TasteAction.lessLikeThis, core).terms, <String>['space']);
  });

  test('using remembered terms keeps that wall in the 500-entry LRU cache', () {
    rememberFeedTerms('f', <String>['space']);
    for (int i = 0; i < 499; i++) {
      rememberFeedTerms('https://example.com/$i', <String>['nature']);
    }
    expect(TasteSignal.forWallpaper(TasteAction.open, _core()).terms, <String>['space']);

    rememberFeedTerms('https://example.com/new', <String>['sky']);

    expect(TasteSignal.forWallpaper(TasteAction.download, _core()).terms, <String>['space']);
    const WallpaperCore evicted = WallpaperCore(
      id: '0',
      source: WallpaperSource.pexels,
      fullUrl: 'https://example.com/0',
      thumbnailUrl: 't',
    );
    expect(TasteSignal.forWallpaper(TasteAction.open, evicted).terms, isEmpty);
  });
}

WallpaperCore _core({String? category}) =>
    WallpaperCore(id: 'w1', source: WallpaperSource.prism, fullUrl: 'f', thumbnailUrl: 't', category: category);
