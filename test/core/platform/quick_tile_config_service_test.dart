import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a session change while preferences load prevents stale WOTD metadata and URL writes', () async {
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final started = Completer<void>();
    final release = Completer<void>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'getAll') {
        started.complete();
        await release.future;
        return <String, Object>{};
      }
      return true;
    });
    SharedPreferences.resetStatic();
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });
    var current = true;
    final pending = QuickTileConfigService.pushWotdUrl(
      '',
      wallDocumentId: 'old-owner-doc',
      featuredDayUtc: DateTime.utc(2026, 8, 24),
      retainedAssetKey: 'wotd:old-owner-doc',
      isCurrent: () => current,
    );
    await started.future;
    current = false;
    release.complete();
    await pending;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(QuickTileConfigService.wotdRetainedKey), isNull);
    expect(prefs.getString(PersistenceKeys.quickTileWotdUrl), isNull);
    expect(calls, <String>['getAll']);
  });

  test('a public Wall of the Day URL clears the link the tile opens for a protected wall', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const String link = 'prism://share?id=doc&source=prism&url=&thumb=preview';
    await QuickTileConfigService.pushWotdUrl('', openLink: link);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(QuickTileConfigService.wotdOpenLinkKey), link);

    await QuickTileConfigService.pushWotdUrl('https://img.example.com/public.jpg');
    expect(prefs.getString(QuickTileConfigService.wotdOpenLinkKey), isNull);
    expect(prefs.getString(PersistenceKeys.quickTileWotdUrl), 'https://img.example.com/public.jpg');

    await QuickTileConfigService.pushWotdUrl('https://img.example.com/public.jpg', openLink: link);
    expect(prefs.getString(QuickTileConfigService.wotdOpenLinkKey), isNull);

    await QuickTileConfigService.pushWotdUrl(
      '',
      wallDocumentId: 'doc',
      featuredDayUtc: DateTime.utc(2026, 10, 29),
      retainedAssetKey: 'wotd:doc',
      openLink: link,
    );
    expect(prefs.getString(QuickTileConfigService.wotdOpenLinkKey), isNull);
    expect(jsonDecode(prefs.getString(QuickTileConfigService.wotdRetainedKey)!), <String, String>{
      'documentId': 'doc',
      'featuredDayUtc': '2026-10-29T00:00:00.000Z',
      'assetKey': 'wotd:doc',
    });
  });

  test('invalid native targets do not become both home and lock', () async {
    for (final target in <String>['', 'invalid', 'HOME']) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.quickTileCategoryName: 'Nature',
        PersistenceKeys.quickTileCategorySource: 'pexels',
        PersistenceKeys.quickTileCategoryTarget: target,
        PersistenceKeys.quickTileWotdTarget: target,
        PersistenceKeys.quickTileFavsTarget: target,
      });

      expect(await QuickTileConfigService.loadCategoryTileConfig(), isNull);
      expect(await QuickTileConfigService.loadWotdTileConfig(), isNull);
      expect(await QuickTileConfigService.loadFavsTileConfig(), isNull);
    }
  });

  test('malformed WOTD preference types are ignored instead of throwing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PersistenceKeys.quickTileWotdTarget: 42,
      PersistenceKeys.quickTileWotdUrl: <String>['not', 'a', 'url'],
    });

    expect(await QuickTileConfigService.loadWotdTileConfig(), isNull);
  });

  test('malformed favourites are discarded before reaching the native tile', () async {
    for (final urls in <String>['["https://example.com/wall.jpg", 1]', '{"url": "wall"}', 'invalid']) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.quickTileFavsTarget: 'home',
        PersistenceKeys.quickTileFavWallUrls: urls,
      });

      final config = await QuickTileConfigService.loadFavsTileConfig();
      expect(config?.target, WallpaperTarget.home);
      expect(config?.wallUrls, isEmpty);
    }
  });

  test('unsupported stored category sources do not become a Pexels category', () async {
    for (final source in <String>['unknown', 'downloaded', 'prism', 'wall_of_the_day', 'typo']) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.quickTileCategoryName: 'Nature',
        PersistenceKeys.quickTileCategorySource: source,
        PersistenceKeys.quickTileCategoryTarget: 'both',
      });

      expect(await QuickTileConfigService.loadCategoryTileConfig(), isNull);
    }
  });

  test('supported category sources round-trip through native preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    for (final source in <WallpaperSource>[WallpaperSource.pexels, WallpaperSource.wallhaven]) {
      await QuickTileConfigService.saveCategoryTileConfig(
        categoryName: 'Nature',
        source: source,
        target: WallpaperTarget.lock,
      );
      final config = await QuickTileConfigService.loadCategoryTileConfig();
      expect(config?.categoryName, 'Nature');
      expect(config?.source, source);
      expect(config?.target, WallpaperTarget.lock);
    }
  });
}
