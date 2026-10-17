import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/views/widgets/wall_of_the_day_card.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/coins_test_backend.dart';
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

  testWidgets('the card carries a Wall of the day tag and names the photographer', (tester) async {
    final handle = tester.ensureSemantics();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    final bloc = _MockWotdBloc();
    when(() => bloc.state).thenReturn(
      WotdState.initial().copyWith(
        status: LoadStatus.success,
        entity: const WallOfTheDayEntity(wallId: 'wotd-2', url: '', thumbnailUrl: '', photographer: 'Ana'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WotdBloc>.value(
          value: bloc,
          child: const SizedBox(width: 366, height: 205, child: WallOfTheDayCard()),
        ),
      ),
    );

    expect(find.text('Wall of the day'), findsOneWidget);
    expect(find.text('by Ana'), findsOneWidget);
    expect(find.bySemanticsLabel('Wall of the day by Ana'), findsOneWidget);
    handle.dispose();
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
    expect(find.text('Wall of the day'), findsNothing);
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
    final Finder pill = find.byKey(const ValueKey<String>('wotd-past-picks-pill'));

    const Size slot = Size(360, 240);

    /// The card in a 360 by 240 slot at the top of a 360 wide phone, like a page of the home carousel.
    Future<void> pumpCard(WidgetTester tester, WallOfTheDayEntity entity, {double textScale = 1}) async {
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
                child: SizedBox.fromSize(size: slot, child: const WallOfTheDayCard()),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a tap on the card reports the view_wotd quest event', (tester) async {
      final CoinsTestBackend backend = CoinsTestBackend();
      await backend.install();
      addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
      final List<String> events = <String>[];
      backend.onCall = (String name, Map<String, dynamic> params) async {
        if (name == 'progressQuest') events.add(params['event'] as String);
        return <String, Object?>{'success': true, 'rev': 1};
      };
      await pumpCard(
        tester,
        const WallOfTheDayEntity(wallId: 'wotd-1', url: '', thumbnailUrl: '', photographer: 'Ana'),
      );

      await tester.tap(find.text('by Ana'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));

      expect(events, <String>['view_wotd']);
    });

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
      final Rect visible = tester.getRect(pill);
      expect(hitTarget.size.height, 48);
      expect(visible.height, 36);
      expect(hitTarget.center, visible.center);

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

    testWidgets('the card names the creator under the Wall of the day tag', (tester) async {
      await pumpCard(tester, _wall);

      expect(find.text('by Ana'), findsOneWidget);
      expect(find.text('Wall of the day'), findsOneWidget);
      expect(
        tester.getRect(find.text('Wall of the day')).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('by Ana')).top),
      );
    });

    testWidgets('a pick with no creator shows only the tag and the pill', (tester) async {
      await pumpCard(tester, const WallOfTheDayEntity(wallId: 'anon', url: '', thumbnailUrl: '', photographer: ''));

      expect(find.text('Wall of the day'), findsOneWidget);
      expect(find.textContaining('by '), findsNothing);
      expect(find.text('Past picks'), findsOneWidget);
    });

    testWidgets('the card fills its 360 by 240 slot', (tester) async {
      await pumpCard(tester, _wall);

      expect(tester.getRect(find.byType(WallOfTheDayCard)), Offset.zero & slot);
    });

    testWidgets(
      'the pill sits at the bottom right of the card, 16 px from the end edge and clear of the retry button',
      (tester) async {
        await pumpCard(tester, _wall);

        final Rect card = tester.getRect(find.byType(WallOfTheDayCard));
        final Rect hitTarget = tester.getRect(pillTarget);
        final Rect creator = tester.getRect(find.text('by Ana'));

        expect(card.right - hitTarget.right, 16);
        expect(hitTarget.top, greaterThanOrEqualTo(card.top));
        expect(hitTarget.left, greaterThanOrEqualTo(card.left));
        expect(hitTarget.center.dy, greaterThan(card.center.dy));
        expect(hitTarget.left, greaterThan(creator.right));
        expect(card.bottom - hitTarget.bottom, 26);
        // The retry button of a failed image sits in the corner. The pill must not cover its centre.
        expect(hitTarget.contains(card.bottomRight - const Offset(24, 24)), isFalse);
      },
    );

    testWidgets('the pill is the current liquid glass pill with a scrim tint and white label', (tester) async {
      await pumpCard(tester, _wall);

      final PrismGlass glass = tester.widget<PrismGlass>(
        find.ancestor(of: pill, matching: find.byType(PrismGlass)).first,
      );
      expect(glass.borderRadius, 18);
      expect(glass.thickness, 16);
      expect(glass.glassColor, Theme.of(tester.element(pill)).colorScheme.scrim.withValues(alpha: 0.4));
      final TextStyle label = tester.widget<Text>(find.text('Past picks')).style!;
      expect(label.color, PrismColors.onPrimary);
      expect(label.fontSize, 13);
      expect(tester.getSize(pill).height, 36);
    });

    for (final double textScale in <double>[1.3, 2]) {
      testWidgets('at $textScale times text the pill keeps a 48 by 48 target and its label inside', (tester) async {
        await pumpCard(tester, _wall, textScale: textScale);

        final Rect hitTarget = tester.getRect(pillTarget);
        final Rect visible = tester.getRect(pill);
        final Rect label = tester.getRect(find.text('Past picks'));

        expect(tester.takeException(), isNull);
        expect(hitTarget.width, greaterThanOrEqualTo(48));
        expect(hitTarget.height, 48);
        expect(visible.height, 36);
        expect(label.left, greaterThan(visible.left));
        expect(label.right, lessThan(visible.right));
        expect(label.top, greaterThanOrEqualTo(visible.top));
        expect(label.bottom, lessThanOrEqualTo(visible.bottom));
      });
    }

    testWidgets('the pill grows with its label up to 1.5x text and no further', (tester) async {
      Future<double> pillWidth(double textScale) async {
        await tester.pumpWidget(const SizedBox());
        await pumpCard(tester, _wall, textScale: textScale);
        return tester.getSize(pill).width;
      }

      final double normal = await pillWidth(1);
      final double large = await pillWidth(1.5);
      final double huge = await pillWidth(2);

      expect(large, greaterThan(normal));
      expect(huge, large);
      expect(tester.renderObject<RenderParagraph>(find.text('Past picks')).textScaler.scale(10), 15);
    });

    testWidgets('a long creator name ellipsizes and leaves the pill in place', (tester) async {
      final String name = 'Ana Maria Rodriguez-Fernandez ' * 4;
      await pumpCard(tester, WallOfTheDayEntity(wallId: 'long', url: '', thumbnailUrl: '', photographer: name));

      final Rect card = tester.getRect(find.byType(WallOfTheDayCard));
      final Rect creator = tester.getRect(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('by ')));

      expect(tester.takeException(), isNull);
      expect(creator.left, greaterThanOrEqualTo(card.left));
      expect(creator.right, lessThanOrEqualTo(card.right));
      expect(creator.right, lessThanOrEqualTo(tester.getRect(pill).left));
    });
  });
}
