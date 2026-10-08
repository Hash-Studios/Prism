import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/views/widgets/wall_of_the_day_card.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

const _wall = WallOfTheDayEntity(wallId: 'card-old', url: '', thumbnailUrl: '', photographer: 'Ana');

void main() {
  testWidgets('wotd_viewed fires once per wall even when the carousel rebuilds the card', (tester) async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);

    final bloc = _MockWotdBloc();
    when(() => bloc.state).thenReturn(
      WotdState.initial().copyWith(
        status: LoadStatus.success,
        entity: const WallOfTheDayEntity(wallId: 'wotd-1', url: '', thumbnailUrl: '', photographer: 'Ana'),
      ),
    );

    // The carousel disposes page 0 when it scrolls away and builds a fresh card when it loops back.
    for (var loop = 0; loop < 3; loop++) {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<WotdBloc>.value(
            value: bloc,
            child: WallOfTheDayCard(key: ValueKey<int>(loop)),
          ),
        ),
      );
    }

    expect(analytics.events.where((e) => e.eventName == 'wotd_viewed'), hasLength(1));
  });

  testWidgets('keeps the old card through refresh and failure, then renders the new or empty result', (tester) async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);

    final bloc = _MockWotdBloc();
    final initial = WotdState.initial().copyWith(status: LoadStatus.success, entity: _wall);
    final states = StreamController<WotdState>.broadcast(sync: true);
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: initial);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WotdBloc>.value(value: bloc, child: const WallOfTheDayCard()),
      ),
    );
    expect(find.text('by Ana'), findsOneWidget);

    states.add(initial.copyWith(status: LoadStatus.loading));
    await tester.pump();
    expect(find.text('by Ana'), findsOneWidget);

    const newWall = WallOfTheDayEntity(wallId: 'card-new', url: '', thumbnailUrl: '', photographer: 'Bea');
    states.add(initial.copyWith(status: LoadStatus.success, entity: newWall));
    await tester.pump();
    expect(find.text('by Bea'), findsOneWidget);
    expect(find.text('by Ana'), findsNothing);

    states.add(initial.copyWith(status: LoadStatus.failure, entity: newWall));
    await tester.pump();
    expect(find.text('by Bea'), findsOneWidget);

    states.add(initial.copyWith(status: LoadStatus.success, entity: null));
    await tester.pump();
    expect(find.text('wall of the day'), findsNothing);
  });

  group('navigation', () {
    late _MockStackRouter router;
    late FakeAppAnalytics analytics;

    setUpAll(() {
      registerFallbackValue(WallpaperDetailRoute());
      registerFallbackValue(const WotdArchiveRoute());
    });

    setUp(() {
      router = _MockStackRouter();
      when(() => router.push(any())).thenAnswer((_) async => null);
      analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
    });

    tearDown(AnalyticsRuntime.reset);

    Future<void> pumpCard(WidgetTester tester, WallOfTheDayEntity entity) async {
      final bloc = _MockWotdBloc();
      when(() => bloc.state).thenReturn(WotdState.initial().copyWith(status: LoadStatus.success, entity: entity));
      await tester.pumpWidget(
        MaterialApp(
          home: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: BlocProvider<WotdBloc>.value(
              value: bloc,
              child: const SizedBox(width: 360, height: 240, child: WallOfTheDayCard()),
            ),
          ),
        ),
      );
    }

    testWidgets('a tap opens the loaded wall, with no second fetch', (tester) async {
      const wallpaper = PrismWallpaper(
        core: WallpaperCore(
          id: 'wotd-1',
          source: WallpaperSource.prism,
          fullUrl: 'https://example.test/full.jpg',
          thumbnailUrl: '',
        ),
        firestoreDocumentId: 'doc-1',
      );
      await pumpCard(
        tester,
        const WallOfTheDayEntity(
          wallId: 'wotd-1',
          url: 'https://example.test/full.jpg',
          thumbnailUrl: '',
          photographer: 'Ana',
          wallpaper: wallpaper,
        ),
      );

      await tester.tap(find.text('wall of the day'));
      await tester.pump();

      final WallpaperDetailRoute route =
          verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
      expect(route.args!.wallId, isNull);
      expect((route.args!.entity! as PrismFeedItem).wallpaper.firestoreDocumentId, 'doc-1');
      expect(analytics.events.where((e) => e.eventName == 'wotd_opened').single.toWireParameters(), {
        'wall_id': 'wotd-1',
        'source': 'card_tap',
      });
    });

    testWidgets('a pick without the loaded wall still opens by id', (tester) async {
      await pumpCard(tester, _wall);

      await tester.tap(find.text('wall of the day'));
      await tester.pump();

      final WallpaperDetailRoute route =
          verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
      expect(route.args!.wallId, 'card-old');
      expect(route.args!.entity, isNull);
    });

    testWidgets('See past picks opens the archive and does not open the wall', (tester) async {
      await pumpCard(tester, _wall);

      await tester.tap(find.text('See past picks'));
      await tester.pump();

      final PageRouteInfo<dynamic> route =
          verify(() => router.push(captureAny())).captured.single as PageRouteInfo<dynamic>;
      expect(route, isA<WotdArchiveRoute>());
      expect(analytics.events.where((e) => e.eventName == 'wotd_opened'), isEmpty);
    });

    testWidgets('the See past picks button is at least 48 by 48', (tester) async {
      await pumpCard(tester, _wall);

      final Size size = tester.getSize(find.widgetWithText(TextButton, 'See past picks'));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });
  });
}
