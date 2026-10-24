import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_tile_image.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

const String _channelPrefix = 'dev.flutter.pigeon.Prism.PrismMediaHostApi';
const String _tag = 'wallpaper';
const Key _backgroundMarkerKey = ValueKey<String>('background-marker');
const Key _flyingPictureKey = ValueKey<String>('flying-picture');
const Key _openDetailKey = ValueKey<String>('open-detail');
const Key _closeDetailKey = ValueKey<String>('close-detail');

Widget _detailPage(Object routeTag) => Scaffold(
  body: Center(
    child: SizedBox(
      width: 280,
      height: 360,
      child: WallpaperDetailHero(
        tag: routeTag,
        radius: 16,
        image: const SizedBox.expand(
          key: _flyingPictureKey,
          child: ColoredBox(color: Colors.blue),
        ),
      ),
    ),
  ),
  floatingActionButton: Builder(
    builder: (context) => FloatingActionButton(
      key: _closeDetailKey,
      onPressed: () => Navigator.of(context).pop(),
      child: const Icon(Icons.close),
    ),
  ),
);

Future<void> _expectMarkerFollowsHero(WidgetTester tester, Rect tileRect, Rect markerRect) async {
  for (var frame = 0; frame < 5 && find.byKey(_flyingPictureKey).evaluate().isEmpty; frame++) {
    await tester.pump();
  }
  expect(find.byKey(_flyingPictureKey), findsOneWidget);
  for (var frame = 0; frame < 5; frame++) {
    final Rect flight = tester.getRect(find.byKey(_flyingPictureKey));
    final double scale = flight.width / tileRect.width;
    final Rect expected = Rect.fromLTWH(
      flight.left + (markerRect.left - tileRect.left) * scale,
      flight.top + (markerRect.top - tileRect.top) * scale,
      markerRect.width * scale,
      markerRect.height * scale,
    );
    expect(tester.getRect(find.byKey(_backgroundMarkerKey)), rectMoreOrLessEquals(expected, epsilon: 0.5));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

class _HeroSourcesRouter extends RootStackRouter {
  _HeroSourcesRouter({required this.source, required this.routeTag});

  final Widget source;
  Object routeTag;

  @override
  RouteType get defaultRouteType => defaultTargetPlatform == TargetPlatform.iOS
      ? const RouteType.adaptive()
      : RouteType.custom(
          duration: PrismDurations.base,
          reverseDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (context.reduceMotion) return child;
            final Animation<double> t = animation.drive(CurveTween(curve: PrismCurves.enter));
            return FadeTransition(
              opacity: t,
              child: AnimatedBuilder(
                animation: t,
                builder: (context, child) => Transform.translate(offset: Offset(24 * (1 - t.value), 0), child: child),
                child: child,
              ),
            );
          },
        );

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Source',
        builder: (_) => Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned.fill(child: source),
              const Positioned(
                left: 450,
                top: 300,
                width: 80,
                height: 40,
                child: ColoredBox(key: _backgroundMarkerKey, color: Colors.red),
              ),
              Positioned(
                right: 24,
                bottom: 24,
                child: Builder(
                  builder: (context) => ElevatedButton(
                    key: _openDetailKey,
                    onPressed: () => context.router.push<void>(const PageRouteInfo<void>('Detail')),
                    child: const Text('Open detail'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    CustomRoute(
      path: '/detail',
      page: PageInfo('Detail', builder: (_) => _detailPage(routeTag)),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
  ];
}

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

  Future<Rect> pumpSource(WidgetTester tester, Widget source) async {
    final _HeroSourcesRouter router = _HeroSourcesRouter(
      source: Stack(children: <Widget>[Positioned(left: 24, top: 48, width: 120, height: 180, child: source)]),
      routeTag: _tag,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await tester.pump();
    final Rect sourceRect = tester.getRect(find.byType(Hero));
    final Rect markerRect = tester.getRect(find.byKey(_backgroundMarkerKey));
    await tester.tap(find.byKey(_openDetailKey));
    await _expectMarkerFollowsHero(tester, sourceRect, markerRect);
    await tester.pumpAndSettle();
    return sourceRect;
  }

  Future<void> expectStraightPopFlight(WidgetTester tester, Rect tileRect) async {
    final Rect detailRect = tester.getRect(find.byKey(_flyingPictureKey));
    expect(detailRect.center.dx, isNot(tileRect.center.dx));
    expect(detailRect.center.dy, isNot(tileRect.center.dy));

    await tester.tap(find.byKey(_closeDetailKey));
    await tester.pump();
    for (final Duration sample in <Duration>[const Duration(milliseconds: 60), const Duration(milliseconds: 60)]) {
      await tester.pump(sample);
      final Rect flightRect = tester.getRect(find.byKey(_flyingPictureKey));
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
    final Rect tileRect = await pumpSource(tester, const PrismImageTile(url: '', heroTag: _tag));

    await expectStraightPopFlight(tester, tileRect);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('favourite image sources pop on a straight Hero flight', (tester) async {
    final Rect tileRect = await pumpSource(
      tester,
      const FavouriteTileImage(thumbnailUrl: '', fullUrl: '', onUnavailable: _noop, heroTag: _tag),
    );

    await expectStraightPopFlight(tester, tileRect);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('downloaded file sources pop on a straight Hero flight', (tester) async {
    final _HeroSourcesRouter router = _HeroSourcesRouter(source: const DownloadsBody(), routeTag: _tag);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await tester.pump();
    await tester.pump();
    final Finder sourceHero = find.byType(Hero);
    expect(sourceHero, findsOneWidget);
    final Hero hero = tester.widget<Hero>(sourceHero);
    expect(hero.tag, startsWith('wall-'));
    router.routeTag = hero.tag;
    final Rect tileRect = tester.getRect(sourceHero);
    final Rect markerRect = tester.getRect(find.byKey(_backgroundMarkerKey));

    await tester.tap(find.byKey(_openDetailKey));
    await _expectMarkerFollowsHero(tester, tileRect, markerRect);
    await tester.pumpAndSettle();
    await expectStraightPopFlight(tester, tileRect);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}));
}

void _noop() {}
