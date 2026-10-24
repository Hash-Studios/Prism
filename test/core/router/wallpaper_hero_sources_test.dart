import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_tile_image.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

const String _channelPrefix = 'dev.flutter.pigeon.Prism.PrismMediaHostApi';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  ByteData? reply(Object value) => PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[value]);

  setUp(() {
    directory = Directory.systemTemp.createTempSync('wallpaper_hero_sources_test-');
    File('${directory.path}/wall.gif').writeAsBytesSync(base64Decode('R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs='));
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt.registerSingleton<DownloadedWallIndex>(DownloadedWallIndex(SettingsLocalDataSource(InMemoryLocalStore())));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      '$_channelPrefix.listDownloads',
      (_) async => reply(DownloadItemsResult(success: true, items: <String>['${directory.path}/wall.gif'])),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      '$_channelPrefix.listDownloads',
      null,
    );
    AnalyticsRuntime.reset();
    await getIt.reset();
    directory.deleteSync(recursive: true);
  });

  const String tag = 'wallpaper';
  const Key flyingPictureKey = ValueKey<String>('flying-picture');
  const Key openDetailKey = ValueKey<String>('open-detail');
  const Key closeDetailKey = ValueKey<String>('close-detail');

  Widget detailPage(Object routeTag) => Scaffold(
    body: Center(
      child: SizedBox(
        width: 280,
        height: 360,
        child: WallpaperDetailHero(
          tag: routeTag,
          radius: 16,
          image: const SizedBox.expand(
            key: flyingPictureKey,
            child: ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    ),
    floatingActionButton: Builder(
      builder: (context) => FloatingActionButton(
        key: closeDetailKey,
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.close),
      ),
    ),
  );

  Future<Rect> pumpSource(WidgetTester tester, Widget source) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(left: 24, top: 48, width: 120, height: 180, child: source),
              Positioned(
                right: 24,
                bottom: 24,
                child: Builder(
                  builder: (context) => ElevatedButton(
                    key: openDetailKey,
                    onPressed: () =>
                        Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => detailPage(tag))),
                    child: const Text('Open detail'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final Rect sourceRect = tester.getRect(find.byType(Hero));
    await tester.tap(find.byKey(openDetailKey));
    await tester.pumpAndSettle();
    return sourceRect;
  }

  Future<void> expectStraightPopFlight(WidgetTester tester, Rect tileRect) async {
    final Rect detailRect = tester.getRect(find.byKey(flyingPictureKey));
    expect(detailRect.center.dx, isNot(tileRect.center.dx));
    expect(detailRect.center.dy, isNot(tileRect.center.dy));

    await tester.tap(find.byKey(closeDetailKey));
    await tester.pump();
    for (final Duration sample in <Duration>[const Duration(milliseconds: 60), const Duration(milliseconds: 60)]) {
      await tester.pump(sample);
      final Rect flightRect = tester.getRect(find.byKey(flyingPictureKey));
      final double progress = (flightRect.width - tileRect.width) / (detailRect.width - tileRect.width);
      expect(progress, allOf(greaterThan(0), lessThan(1)));
      final Rect expected = Rect.lerp(tileRect, detailRect, progress)!;
      expect(flightRect.left, closeTo(expected.left, 0.5));
      expect(flightRect.top, closeTo(expected.top, 0.5));
      expect(flightRect.right, closeTo(expected.right, 0.5));
      expect(flightRect.bottom, closeTo(expected.bottom, 0.5));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Prism image sources pop on a straight Hero flight', (tester) async {
    final Rect tileRect = await pumpSource(tester, const PrismImageTile(url: '', heroTag: tag));

    await expectStraightPopFlight(tester, tileRect);
  });

  testWidgets('favourite image sources pop on a straight Hero flight', (tester) async {
    final Rect tileRect = await pumpSource(
      tester,
      const FavouriteTileImage(thumbnailUrl: '', fullUrl: '', onUnavailable: _noop, heroTag: tag),
    );

    await expectStraightPopFlight(tester, tileRect);
  });

  testWidgets('downloaded file sources pop on a straight Hero flight', (tester) async {
    Object? downloadTag;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              const DownloadsBody(),
              Positioned(
                right: 24,
                bottom: 24,
                child: Builder(
                  builder: (context) => ElevatedButton(
                    key: openDetailKey,
                    onPressed: () => Navigator.of(
                      context,
                    ).push<void>(MaterialPageRoute<void>(builder: (_) => detailPage(downloadTag!))),
                    child: const Text('Open detail'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final Finder sourceHero = find.byType(Hero);
    expect(sourceHero, findsOneWidget);
    final Hero hero = tester.widget<Hero>(sourceHero);
    expect(hero.tag, startsWith('wall-'));
    downloadTag = hero.tag;
    final Rect tileRect = tester.getRect(sourceHero);

    await tester.tap(find.byKey(openDetailKey));
    await tester.pumpAndSettle();
    await expectStraightPopFlight(tester, tileRect);
  });
}

void _noop() {}
