import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/wallpapers/carousel_dots.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/views/widgets/wall_of_the_day_card.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    expect(find.text('WALL OF THE DAY'), findsNothing);
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

    final Finder pillTarget = find.ancestor(of: find.text('Past picks'), matching: find.byType(GestureDetector)).first;

    const Size slot = Size(360, 240);
    const int slideCount = 5;

    /// The card in a 360 by 240 slot at the top of a 360 wide phone, stacked with the dots as the home carousel does.
    Future<void> pumpCard(
      WidgetTester tester,
      WallOfTheDayEntity entity, {
      double textScale = 1,
      bool withDots = false,
    }) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bloc = _MockWotdBloc();
      when(() => bloc.state).thenReturn(WotdState.initial().copyWith(status: LoadStatus.success, entity: entity));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: BlocProvider<WotdBloc>.value(
              value: bloc,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.fromSize(
                  size: slot,
                  child: Stack(
                    alignment: AlignmentDirectional.bottomEnd,
                    children: [
                      const SizedBox.expand(child: WallOfTheDayCard()),
                      if (withDots) const CarouselDots(current: 0, count: slideCount),
                    ],
                  ),
                ),
              ),
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

      await tester.tap(find.text('by Ana'));
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

      await tester.tap(find.text('by Ana'));
      await tester.pump();

      final WallpaperDetailRoute route =
          verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
      expect(route.args!.wallId, 'card-old');
      expect(route.args!.entity, isNull);
    });

    testWidgets('the Past picks pill opens the archive and does not open the wall', (tester) async {
      await pumpCard(tester, _wall);

      await tester.tap(find.text('Past picks'));
      await tester.pump();

      final PageRouteInfo<dynamic> route =
          verify(() => router.push(captureAny())).captured.single as PageRouteInfo<dynamic>;
      expect(route, isA<WotdArchiveRoute>());
      expect(analytics.events.where((e) => e.eventName == 'wotd_opened'), isEmpty);
    });

    testWidgets('the Past picks hit target is 48 by 48 around a 36 high pill', (tester) async {
      await pumpCard(tester, _wall);

      final Rect hitTarget = tester.getRect(pillTarget);
      final Rect glass = tester.getRect(find.byType(PrismGlass));
      expect(hitTarget.size.height, 48);
      expect(glass.height, 36);
      expect(hitTarget.center, glass.center);

      await tester.tapAt(hitTarget.topCenter + const Offset(0, 2));
      await tester.pump();

      expect(verify(() => router.push(captureAny())).captured.single, isA<WotdArchiveRoute>());
    });

    testWidgets('the pill is announced as a button that opens the archive', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCard(tester, _wall);

      final Finder pill = find.bySemanticsLabel('See past walls of the day');
      expect(pill, findsOneWidget);
      final SemanticsNode node = tester.getSemantics(pill);
      expect(node, isSemantics(label: 'See past walls of the day', isButton: true, hasTapAction: true));

      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
      );
      await tester.pump();

      expect(verify(() => router.push(captureAny())).captured.single, isA<WotdArchiveRoute>());
      expect(analytics.events.where((e) => e.eventName == 'wotd_opened'), isEmpty);
      handle.dispose();
    });

    testWidgets('the caption reads by the creator, with the overline above it', (tester) async {
      await pumpCard(tester, _wall);

      expect(find.text('by Ana'), findsOneWidget);
      expect(find.text('WALL OF THE DAY'), findsOneWidget);
      expect(
        tester.getRect(find.text('WALL OF THE DAY')).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('by Ana')).top),
      );
    });

    testWidgets('a pick with no creator shows only the overline', (tester) async {
      await pumpCard(tester, const WallOfTheDayEntity(wallId: 'anon', url: '', thumbnailUrl: '', photographer: ''));

      expect(find.text('WALL OF THE DAY'), findsOneWidget);
      expect(find.textContaining('by '), findsNothing);
      expect(find.text('Past picks'), findsOneWidget);
    });

    testWidgets('the card fills its 360 by 240 slot', (tester) async {
      await pumpCard(tester, _wall);

      expect(tester.getRect(find.byType(WallOfTheDayCard)), Offset.zero & slot);
    });

    testWidgets('the caption row sits 16 px from the sides and clear of the real dot row', (tester) async {
      await pumpCard(tester, _wall, withDots: true);

      final Rect card = tester.getRect(find.byType(WallOfTheDayCard));
      final Rect dotRow = tester.getRect(find.descendant(of: find.byType(CarouselDots), matching: find.byType(Row)));
      final Rect pill = tester.getRect(pillTarget);
      final Rect creator = tester.getRect(find.text('by Ana'));

      expect(card, Offset.zero & slot);
      expect(dotRow, const Rect.fromLTRB(0, 210, 360, 240));
      expect(tester.getRect(find.text('WALL OF THE DAY')).left - card.left, 16);
      expect(card.right - pill.right, 16);
      expect(pill.bottom, lessThanOrEqualTo(dotRow.top));
      expect(creator.bottom, lessThanOrEqualTo(dotRow.top));
    });

    for (final double textScale in <double>[1.3, 2]) {
      group('at $textScale times text', () {
        testWidgets('the caption and the pill stay inside the card and clear of the dots', (tester) async {
          await pumpCard(tester, _wall, textScale: textScale, withDots: true);

          final Rect card = tester.getRect(find.byType(WallOfTheDayCard));
          final Rect dotRow = tester.getRect(
            find.descendant(of: find.byType(CarouselDots), matching: find.byType(Row)),
          );
          final Rect pill = tester.getRect(pillTarget);
          final Rect eyebrow = tester.getRect(find.text('WALL OF THE DAY'));
          final Rect creator = tester.getRect(find.textContaining('by '));

          expect(tester.takeException(), isNull);
          expect(card, Offset.zero & slot);
          expect(eyebrow.top, greaterThanOrEqualTo(card.top));
          expect(eyebrow.left - card.left, 16);
          expect(eyebrow.right, lessThanOrEqualTo(pill.left));
          expect(creator.right, lessThanOrEqualTo(pill.left));
          expect(creator.bottom, lessThanOrEqualTo(dotRow.top));
          expect(pill.bottom, lessThanOrEqualTo(dotRow.top));
          expect(card.right - pill.right, 16);
        });

        testWidgets('the pill keeps a 48 by 48 hit target and its label inside the glass', (tester) async {
          await pumpCard(tester, _wall, textScale: textScale);

          final Rect hitTarget = tester.getRect(pillTarget);
          final Rect glass = tester.getRect(find.byType(PrismGlass));
          final Rect label = tester.getRect(find.text('Past picks'));

          expect(hitTarget.width, greaterThanOrEqualTo(48));
          expect(hitTarget.height, 48);
          expect(glass.height, 36);
          expect(label.left, greaterThan(glass.left));
          expect(label.right, lessThan(glass.right));
          expect(label.top, greaterThanOrEqualTo(glass.top));
          expect(label.bottom, lessThanOrEqualTo(glass.bottom));
        });
      });
    }

    testWidgets('the caption scales with the system text up to 1.5x and no further', (tester) async {
      double scaleOf(String text) => tester.renderObject<RenderParagraph>(find.text(text)).textScaler.scale(10);

      await pumpCard(tester, _wall, textScale: 1.3);
      expect(scaleOf('WALL OF THE DAY'), 13);
      expect(scaleOf('by Ana'), 13);

      await tester.pumpWidget(const SizedBox());
      await pumpCard(tester, _wall, textScale: 2);
      expect(scaleOf('WALL OF THE DAY'), 15);
      expect(scaleOf('by Ana'), 15);
    });

    testWidgets('the Past picks glass is the thin 16 refraction of a small pill', (tester) async {
      await pumpCard(tester, _wall);

      expect(tester.widget<PrismGlass>(find.byType(PrismGlass)).thickness, 16);
    });

    testWidgets('the pill grows with its label up to 1.5x text and no further', (tester) async {
      Future<double> pillWidth(double textScale) async {
        await tester.pumpWidget(const SizedBox());
        await pumpCard(tester, _wall, textScale: textScale);
        return tester.getSize(find.byType(PrismGlass)).width;
      }

      final double normal = await pillWidth(1);
      final double large = await pillWidth(1.5);
      final double huge = await pillWidth(2);

      expect(large, greaterThan(normal));
      expect(huge, large);
      expect(tester.renderObject<RenderParagraph>(find.text('Past picks')).textScaler.scale(10), 15);
    });

    testWidgets('the scrim covers the bottom 60 percent and is at least 30 percent dark under the eyebrow', (
      tester,
    ) async {
      await pumpCard(tester, _wall);

      final Finder scrimBox = find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).gradient != null,
      );
      final LinearGradient scrim =
          (tester.widget<DecoratedBox>(scrimBox).decoration as BoxDecoration).gradient! as LinearGradient;
      final Rect scrimRect = tester.getRect(scrimBox);
      final double eyebrowCentre = tester.getRect(find.text('WALL OF THE DAY')).center.dy;
      final double depth = (eyebrowCentre - scrimRect.top) / scrimRect.height;
      final List<double> stops = scrim.stops!;
      final int segment = stops.indexWhere((stop) => depth <= stop);
      final double along = (depth - stops[segment - 1]) / (stops[segment] - stops[segment - 1]);
      final double alphaUnderEyebrow =
          scrim.colors[segment - 1].a + along * (scrim.colors[segment].a - scrim.colors[segment - 1].a);

      expect(scrimRect, const Rect.fromLTRB(0, 96, 360, 240));
      expect(depth, inExclusiveRange(stops[1], 1));
      expect(alphaUnderEyebrow, greaterThanOrEqualTo(0.3));
      expect(scrim.colors.last.a, closeTo(0.65, 0.001));
    });

    testWidgets('a long creator name ellipsizes and leaves the pill in place', (tester) async {
      final String name = 'Ana Maria Rodriguez-Fernandez ' * 4;
      await pumpCard(tester, WallOfTheDayEntity(wallId: 'long', url: '', thumbnailUrl: '', photographer: name));

      final Rect card = tester.getRect(find.byType(WallOfTheDayCard));
      final Rect pill = tester.getRect(pillTarget);
      final Rect creator = tester.getRect(find.text('by $name'));

      expect(tester.takeException(), isNull);
      expect(creator.right, lessThanOrEqualTo(pill.left));
      expect(card.right - pill.right, 16);
    });
  });
}
