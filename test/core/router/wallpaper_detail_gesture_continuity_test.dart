import 'dart:async';

import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _background = ValueKey<String>('gesture-background');
const _foreground = ValueKey<String>('gesture-foreground');

class _GestureRouter extends RootStackRouter {
  ModalRoute<dynamic>? detail;

  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Grid',
        builder: (_) => const Scaffold(body: SizedBox.expand(key: _background)),
      ),
    ),
    CustomRoute(
      path: '/detail',
      page: PageInfo(
        'Detail',
        builder: (_) => Builder(
          builder: (context) {
            detail = ModalRoute.of(context);
            return const Scaffold(body: SizedBox.expand(key: _foreground));
          },
        ),
      ),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
  ];
}

Future<_GestureRouter> _open(WidgetTester tester, {bool reduceMotion = false, Duration? entryProgress}) async {
  final router = _GestureRouter();
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
  unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
  if (entryProgress == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
    await tester.pump(entryProgress);
  }
  return router;
}

Rect _backgroundRect(WidgetTester tester) => tester.getRect(find.byKey(_background, skipOffstage: false));

void _expectNativePositions(WidgetTester tester, _GestureRouter router) {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final value = router.detail!.animation!.value;
  expect(tester.getRect(find.byKey(_foreground)).left, closeTo(width * (1 - value), 0.01));
  expect(_backgroundRect(tester).left, closeTo(-width * value / 3, 0.01));
  expect(_backgroundRect(tester).width, width);
}

void main() {
  for (final entryMilliseconds in [1, 60, 159]) {
    testWidgets('iOS no-tile pop at ${entryMilliseconds}ms reverses its fade without teleporting either page', (
      tester,
    ) async {
      final router = await _open(tester, entryProgress: Duration(milliseconds: entryMilliseconds));
      expect(router.detail!.animation!.status, AnimationStatus.forward);
      final before = tester.getRect(find.byKey(_foreground));
      final fadeBefore = tester
          .widget<FadeTransition>(
            find.ancestor(of: find.byKey(_foreground), matching: find.byType(FadeTransition)).first,
          )
          .opacity
          .value;
      expect(fadeBefore, inExclusiveRange(0, 1));
      expect(before, const Rect.fromLTWH(0, 0, 800, 600));

      unawaited(router.maybePop<void>());
      await tester.pump();
      expect(tester.getRect(find.byKey(_foreground)), before);
      var previousOpacity = fadeBefore;
      var frames = 0;
      while (router.detail!.animation!.isAnimating) {
        expect(tester.getRect(find.byKey(_foreground)), before);
        expect(_backgroundRect(tester), before);
        final opacity = tester
            .widget<FadeTransition>(
              find.ancestor(of: find.byKey(_foreground), matching: find.byType(FadeTransition)).first,
            )
            .opacity
            .value;
        expect(opacity, lessThanOrEqualTo(previousOpacity));
        previousOpacity = opacity;
        frames++;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(frames, greaterThan(0));
      await tester.pumpAndSettle();
      expect(router.current.name, 'Grid');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  for (final commit in [false, true]) {
    testWidgets('iOS ${commit ? 'committed' : 'cancelled'} edge back stays linear through release and settlement', (
      tester,
    ) async {
      final router = await _open(tester);
      final gesture = await tester.startGesture(const Offset(1, 250));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.moveBy(Offset(commit ? 440 : 80, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final valueBeforeRelease = router.detail!.animation!.value;
      final foregroundBeforeRelease = tester.getRect(find.byKey(_foreground));
      final backgroundBeforeRelease = _backgroundRect(tester);
      _expectNativePositions(tester, router);

      await gesture.up();
      await tester.pump();
      expect(router.detail!.animation!.value, valueBeforeRelease);
      expect(tester.getRect(find.byKey(_foreground)), foregroundBeforeRelease);
      expect(_backgroundRect(tester), backgroundBeforeRelease);
      expect(router.detail!.animation!.status, commit ? AnimationStatus.reverse : AnimationStatus.forward);

      var settlementFrames = 0;
      while (router.detail!.animation!.isAnimating) {
        expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
        _expectNativePositions(tester, router);
        settlementFrames++;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(settlementFrames, greaterThan(3));
      await tester.pumpAndSettle();
      expect(router.navigatorKey.currentState!.userGestureInProgress, isFalse);
      expect(router.current.name, commit ? 'Grid' : 'Detail');
      expect(_backgroundRect(tester), const Rect.fromLTWH(0, 0, 800, 600));
      if (!commit) expect(tester.getRect(find.byKey(_foreground)), const Rect.fromLTWH(0, 0, 800, 600));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('iOS no-tile programmatic pop slides both pages on the native reverse curve', (tester) async {
    final router = await _open(tester);
    expect(_backgroundRect(tester).left, 0);
    unawaited(router.maybePop<void>());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    var frames = 0;
    while (router.detail!.animation!.isAnimating) {
      final transition = tester.widget<cupertino.CupertinoPageTransition>(
        find.ancestor(of: find.byKey(_foreground), matching: find.byType(cupertino.CupertinoPageTransition)).first,
      );
      expect(transition.linearTransition, isFalse);
      final value = router.detail!.animation!.value;
      final foregroundCurve = Curves.fastEaseInToSlowEaseOut.flipped.transform(value);
      final backgroundCurve = Curves.easeInToLinear.transform(value);
      expect(tester.getRect(find.byKey(_foreground)).left, closeTo(800 * (1 - foregroundCurve), 0.01));
      expect(_backgroundRect(tester).left, closeTo(-800 * backgroundCurve / 3, 0.01));
      expect(_backgroundRect(tester).width, 800);
      frames++;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(frames, greaterThan(3));
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
    expect(_backgroundRect(tester), const Rect.fromLTWH(0, 0, 800, 600));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS reduced-motion gesture changes navigation without moving either page on release', (tester) async {
    final router = await _open(tester, reduceMotion: true);
    expect(router.detail!.transitionDuration, Duration.zero);
    final gesture = await tester.startGesture(const Offset(1, 250));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(440, 0));
    await tester.pump();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
    expect(tester.getRect(find.byKey(_foreground)), const Rect.fromLTWH(0, 0, 800, 600));
    expect(_backgroundRect(tester), const Rect.fromLTWH(0, 0, 800, 600));
    await gesture.up();
    await tester.pump();
    while (router.detail!.animation!.isAnimating) {
      expect(tester.getRect(find.byKey(_foreground)), const Rect.fromLTWH(0, 0, 800, 600));
      expect(_backgroundRect(tester), const Rect.fromLTWH(0, 0, 800, 600));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
