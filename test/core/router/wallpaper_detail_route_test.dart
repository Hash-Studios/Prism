import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _tileKey = ValueKey<String>('tile');
const _artKey = ValueKey<String>('detail-art');
const _bodyKey = ValueKey<String>('detail-body');

class _TestRouter extends RootStackRouter {
  _TestRouter({this.allowPop = true});

  final bool allowPop;
  ModalRoute<dynamic>? detailRoute;

  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Grid',
        builder: (_) => const Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 40,
                top: 120,
                width: 100,
                height: 140,
                child: Hero(
                  tag: 'wall',
                  child: ColoredBox(key: _tileKey, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    CustomRoute(
      path: '/detail',
      page: PageInfo(
        'Detail',
        builder: (_) => Builder(
          builder: (context) {
            detailRoute = ModalRoute.of(context);
            return PopScope(
              canPop: allowPop,
              child: Scaffold(
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeroMode(
                      enabled: !context.reduceMotion,
                      child: const Hero(
                        tag: 'wall',
                        child: SizedBox(
                          height: 300,
                          child: ColoredBox(key: _artKey, color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(key: _bodyKey, height: 100, child: _Counter()),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
  ];
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => count++), child: Text('count $count'));
}

Future<_TestRouter> _pumpRouter(WidgetTester tester, {bool reduceMotion = false, bool allowPop = true}) async {
  final router = _TestRouter(allowPop: allowPop);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router.config(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform opens in place while its Hero expands, then returns a typed result', (tester) async {
      final router = await _pumpRouter(tester);
      final tile = tester.getRect(find.byKey(_tileKey));
      final result = router.push<int>(const PageRouteInfo<void>('Detail'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(tester.getRect(find.byKey(_artKey)).width, closeTo(tile.width, 1));
      expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
      expect(router.detailRoute!.transitionDuration, PrismDurations.base);
      expect(router.detailRoute!.settings, same(router.stack.last));
      expect(router.current.animationCompletion, isNotNull);

      double lastWidth = tile.width;
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        final flying = tester.getRect(find.byKey(_artKey));
        expect(flying.width, greaterThan(lastWidth));
        expect(flying.width, lessThanOrEqualTo(800));
        expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
        final fade = tester.widget<FadeTransition>(
          find.ancestor(of: find.byKey(_bodyKey), matching: find.byType(FadeTransition)).first,
        );
        expect(fade.opacity.value, closeTo(PrismCurves.enter.transform(((i + 1) * 60 + 1) / 240), 0.001));
        lastWidth = flying.width;
      }
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_artKey)), const Rect.fromLTWH(0, 0, 800, 300));
      expect(router.current.animationCompletion, isNull);

      unawaited(router.maybePop<int>(7));
      await tester.pumpAndSettle();
      expect(await result, 7);
      expect(router.current.name, 'Grid');
      expect(tester.getRect(find.byKey(_tileKey)), tile);
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform reduced motion opens immediately without a Hero flight or fade', (tester) async {
      final router = await _pumpRouter(tester, reduceMotion: true);
      unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
      await tester.pump();
      await tester.pump();

      expect(router.detailRoute!.transitionDuration, Duration.zero);
      expect(router.detailRoute!.animation!.isCompleted, isTrue);
      expect(tester.getRect(find.byKey(_artKey)), const Rect.fromLTWH(0, 0, 800, 300));
      expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(of: find.byKey(_bodyKey), matching: find.byType(FadeTransition)),
      );
      expect(fades.every((fade) => fade.opacity.value == 1), isTrue);
      unawaited(router.maybePop<void>());
      await tester.pumpAndSettle();
      expect(router.current.name, 'Grid');
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('iOS edge back follows the finger, cancels without losing state, and completes', (tester) async {
    final router = await _pumpRouter(tester);
    unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('count 0'));
    await tester.pump();

    final cancel = await tester.startGesture(const Offset(1, 250));
    await cancel.moveBy(const Offset(100, 0));
    await tester.pump();
    await cancel.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dx, closeTo(180, 1));
    await tester.pump(const Duration(milliseconds: 500));
    await cancel.up();
    await tester.pumpAndSettle();
    expect(router.current.name, 'Detail');
    expect(find.text('count 1'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));

    final complete = await tester.startGesture(const Offset(1, 250));
    await complete.moveBy(const Offset(500, 0));
    await tester.pump();
    await complete.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dx, greaterThan(400));
    await complete.up();
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
    expect(find.byKey(_tileKey), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS reduced motion keeps edge back interactive without translating the page', (tester) async {
    final router = await _pumpRouter(tester, reduceMotion: true);
    unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(1, 250));
    await gesture.moveBy(const Offset(500, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
    expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS respects a PopScope that blocks back navigation', (tester) async {
    final router = await _pumpRouter(tester, allowPop: false);
    unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(1, 250), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isFalse);
    expect(tester.getTopLeft(find.byKey(_bodyKey)), const Offset(0, 300));
    expect(await router.maybePop<void>(), isTrue);
    await tester.pumpAndSettle();
    expect(router.current.name, 'Detail');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
