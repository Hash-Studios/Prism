import 'dart:async';

import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/widgets/prism_sheet/prism_sheet_route.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _detailKey = ValueKey<String>('contract-detail');

class _ContractRouter extends RootStackRouter {
  final Map<String, PageRoute<dynamic>> builtRoutes = {};

  Widget _page(String name) => Builder(
    builder: (context) {
      builtRoutes[name] = ModalRoute.of(context)! as PageRoute<dynamic>;
      return Scaffold(body: Text(name, key: name == 'Detail' ? _detailKey : null));
    },
  );

  @override
  RouteType get defaultRouteType => defaultTargetPlatform == TargetPlatform.iOS
      ? const RouteType.adaptive()
      : RouteType.custom(
          duration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        );

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo('Grid', builder: (_) => _page('Grid')),
    ),
    CustomRoute(
      path: '/detail',
      page: PageInfo('Detail', builder: (_) => _page('Detail')),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
    AutoRoute(
      path: '/next',
      page: PageInfo('Next', builder: (_) => _page('Next')),
    ),
    AutoRoute(
      path: '/dialog',
      page: PageInfo('Dialog', builder: (_) => _page('Dialog')),
      fullscreenDialog: true,
    ),
    CustomRoute(
      path: '/clock-preview',
      page: PageInfo('Clock', builder: (_) => _page('Clock')),
      fullscreenDialog: true,
      opaque: false,
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  ];
}

Future<_ContractRouter> _pumpRouter(
  WidgetTester tester, {
  bool reduceMotion = false,
  ValueNotifier<bool>? tickerEnabled,
}) async {
  final router = _ContractRouter();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
  final app = MaterialApp.router(
    routerConfig: router.config(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
  );
  await tester.pumpWidget(
    tickerEnabled == null
        ? app
        : ValueListenableBuilder<bool>(
            valueListenable: tickerEnabled,
            child: app,
            builder: (_, enabled, child) => TickerMode(enabled: enabled, child: child!),
          ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<PageRoute<dynamic>> _openDetail(WidgetTester tester, _ContractRouter router) async {
  unawaited(router.push<int>(const PageRouteInfo<void>('Detail')));
  await tester.pumpAndSettle();
  return router.builtRoutes['Detail']!;
}

void main() {
  testWidgets('Android keeps non-predictive system back without claiming an interactive preview', (tester) async {
    final router = await _pumpRouter(tester);
    final detail = await _openDetail(tester, router);
    const codec = StandardMethodCodec();
    Object? accepted;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      codec.encodeMethodCall(
        const MethodCall('startBackGesture', {
          'touchOffset': [5.0, 300.0],
          'progress': 0.0,
          'swipeEdge': 0,
        }),
      ),
      (reply) => accepted = codec.decodeEnvelope(reply!),
    );
    await tester.pump();
    expect(accepted, isFalse);
    expect(detail.navigator!.userGestureInProgress, isFalse);
    expect(detail.animation!.value, 1);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      codec.encodeMethodCall(const MethodCall('commitBackGesture')),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
    expect(find.byKey(_detailKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform navigating to the grid while a detail is open closes the detail', (tester) async {
      // A deep link to Home while a wallpaper is open navigates the router under the detail; the detail must finish
      // its closing animation and leave, not stay on screen over the grid.
      final router = await _pumpRouter(tester);
      await _openDetail(tester, router);
      unawaited(router.navigate(const PageRouteInfo<void>('Grid')));
      await tester.pumpAndSettle();
      expect(router.current.name, 'Grid');
      expect(find.byKey(_detailKey), findsNothing);
    }, variant: TargetPlatformVariant({platform}));
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform controller runs 300 ms each way, and a slow first frame counts as one frame', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);
      final result = router.push<int>(const PageRouteInfo<void>('Detail'));
      await tester.pump();
      await tester.pump();
      final detail = router.builtRoutes['Detail']!;
      expect(detail.transitionDuration, wallpaperDetailZoomDuration);
      expect(detail.reverseTransitionDuration, wallpaperDetailZoomDuration);
      expect(wallpaperDetailZoomDuration, const Duration(milliseconds: 300));
      // A 150 ms frame (the one that builds the page) moves the zoom by one 60 Hz frame only.
      await tester.pump(const Duration(milliseconds: 150));
      expect(detail.animation!.value, closeTo(1 / 18, 0.01));
      await tester.pump(const Duration(microseconds: 133333));
      expect(detail.animation!.value, closeTo(0.5, 0.02));
      await tester.pump(const Duration(milliseconds: 151));
      expect(detail.animation!.isCompleted, isTrue);

      await router.maybePop<int>(42);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(detail.animation!.value, closeTo(1 - 1 / 18, 0.01));
      await tester.pump(const Duration(microseconds: 133333));
      expect(detail.animation!.value, closeTo(0.5, 0.02));
      await tester.pump(const Duration(milliseconds: 151));
      expect(await result, 42);
      expect(router.current.name, 'Grid');
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform frame-phase restarts reset the slow-first-step clock in both directions', (tester) async {
      final router = await _pumpRouter(tester);
      final detail = await _openDetail(tester, router);
      final controller = detail.createAnimationController();
      addTearDown(controller.dispose);

      unawaited(controller.forward());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.value, closeTo(1 / 18, 0.001));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.isCompleted, isTrue);

      SchedulerBinding.instance.scheduleFrameCallback((_) => unawaited(controller.reverse()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      expect(controller.value, closeTo(1 - 16 / 300, 0.001));
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.value, closeTo(1 - 32 / 300, 0.001));
      await tester.pumpAndSettle();
      expect(controller.isDismissed, isTrue);

      // Leave a nonzero skipped interval in the reverse run, then restart forward during a frame too.
      unawaited(controller.reverse(from: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.value, closeTo(1 - 1 / 18, 0.001));
      SchedulerBinding.instance.scheduleFrameCallback((_) => unawaited(controller.forward(from: 0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      expect(controller.value, closeTo(16 / 300, 0.001));
      await tester.pumpAndSettle();
      expect(controller.isCompleted, isTrue);
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform initially muted starts cap the first step and keep navigator TickerMode', (tester) async {
      final tickerEnabled = ValueNotifier<bool>(true);
      addTearDown(tickerEnabled.dispose);
      final router = await _pumpRouter(tester, tickerEnabled: tickerEnabled);
      final detail = await _openDetail(tester, router);
      final controller = detail.createAnimationController();
      addTearDown(controller.dispose);
      tickerEnabled.value = false;
      await tester.pump();
      SchedulerBinding.instance.scheduleFrameCallback((_) => unawaited(controller.forward()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.value, 0);
      expect(controller.isAnimating, isTrue);

      tickerEnabled.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.value, closeTo(1 / 18, 0.001));
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.value, closeTo((16.667 + 16) / 300, 0.001));

      tickerEnabled.value = false;
      await tester.pump();
      final beforeMute = controller.value;
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.value, beforeMute);
      tickerEnabled.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        controller.value,
        closeTo(beforeMute + 166 / 300, 0.001),
        reason: 'unmuting the same run must not reset its elapsed time',
      );
      await tester.pumpAndSettle();
      expect(controller.isCompleted, isTrue);
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform zero-duration controllers settle even when the navigator is muted', (tester) async {
      final tickerEnabled = ValueNotifier<bool>(true);
      addTearDown(tickerEnabled.dispose);
      final router = await _pumpRouter(tester, reduceMotion: true, tickerEnabled: tickerEnabled);
      final detail = await _openDetail(tester, router);
      final controller = detail.createAnimationController();
      addTearDown(controller.dispose);
      tickerEnabled.value = false;
      await tester.pump();
      await controller.forward();
      expect(controller.isCompleted, isTrue);
      await controller.reverse();
      expect(controller.isDismissed, isTrue);
      expect(controller.isAnimating, isFalse);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform reduced motion completes the controller immediately in both directions', (tester) async {
      final router = await _pumpRouter(tester, reduceMotion: true);
      final detail = await _openDetail(tester, router);
      expect(detail.transitionDuration, Duration.zero);
      expect(detail.reverseTransitionDuration, Duration.zero);
      expect(detail.animation!.isCompleted, isTrue);
      unawaited(router.maybePop<int>());
      await tester.pump();
      await tester.pump();
      expect(router.current.name, 'Grid');
      expect(find.byKey(_detailKey), findsNothing);
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform keeps non-dismissible barriers and route semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      final router = await _pumpRouter(tester);
      final detail = await _openDetail(tester, router);
      expect(detail.settings, same(router.stack.last));
      expect(detail.maintainState, isTrue);
      expect(detail.opaque, isTrue);
      expect(detail.barrierColor, isNull);
      expect(detail.barrierLabel, isNull);
      expect(detail.barrierDismissible, isFalse);
      final scopes = tester.widgetList<Semantics>(
        find.ancestor(of: find.byKey(_detailKey), matching: find.byType(Semantics)),
      );
      expect(scopes.where((scope) => scope.properties.scopesRoute == true), hasLength(1));
      expect(scopes.singleWhere((scope) => scope.properties.scopesRoute == true).explicitChildNodes, isTrue);
      expect(find.bySemanticsLabel('Detail'), findsOneWidget);
      semantics.dispose();
    }, variant: TargetPlatformVariant({platform}));

    testWidgets('$platform detail coordinates its secondary animation with the next ordinary route', (tester) async {
      final router = await _pumpRouter(tester);
      final detail = await _openDetail(tester, router);
      final before = tester.getTopLeft(find.byKey(_detailKey));
      unawaited(router.push<void>(const PageRouteInfo<void>('Next')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final next = router.builtRoutes['Next']!;
      if (platform == TargetPlatform.iOS) {
        expect(tester.getTopLeft(find.byKey(_detailKey, skipOffstage: false)).dx, lessThan(before.dx));
      }
      expect(detail.secondaryAnimation!.value, closeTo(next.animation!.value, 0.001));
      expect(detail.secondaryAnimation!.value, greaterThan(0));
      expect(detail.canTransitionTo(next), isTrue);
      expect(next.canTransitionFrom(detail), isTrue);
      await tester.pumpAndSettle();
      unawaited(router.maybePop<void>());
      await tester.pumpAndSettle();
      expect(detail.secondaryAnimation!.value, 0);
      expect(find.byKey(_detailKey), findsOneWidget);
    }, variant: TargetPlatformVariant({platform}));

    for (final routeName in ['Clock', 'Dialog']) {
      testWidgets('$platform $routeName fullscreen dialog does not animate the detail behind it', (tester) async {
        final router = await _pumpRouter(tester);
        final detail = await _openDetail(tester, router);
        final before = tester.getRect(find.byKey(_detailKey));
        unawaited(router.push<void>(PageRouteInfo<void>(routeName)));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(detail.secondaryAnimation!.value, 0);
        expect(tester.getRect(find.byKey(_detailKey, skipOffstage: false)), before);
        await tester.pumpAndSettle();
        unawaited(router.maybePop<void>());
        await tester.pumpAndSettle();
        expect(router.current.name, 'Detail');
        expect(tester.getRect(find.byKey(_detailKey)), before);
      }, variant: TargetPlatformVariant({platform}));
    }

    testWidgets('$platform Sheet does not animate the detail behind it', (tester) async {
      final router = await _pumpRouter(tester);
      final detail = await _openDetail(tester, router);
      final before = tester.getRect(find.byKey(_detailKey));
      unawaited(
        showPrismSheet<void>(
          tester.element(find.byKey(_detailKey)),
          builder: (_) => const SizedBox(height: 200, child: Text('Sheet')),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('Sheet'), findsOneWidget);
      expect(detail.secondaryAnimation!.value, 0);
      expect(tester.getRect(find.byKey(_detailKey, skipOffstage: false)), before);
      await tester.pumpAndSettle();
      expect(detail.secondaryAnimation!.value, 0);
      expect(tester.getRect(find.byKey(_detailKey)), before);
    }, variant: TargetPlatformVariant({platform}));
  }
}
