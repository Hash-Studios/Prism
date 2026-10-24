import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

Future<_ContractRouter> _pumpRouter(WidgetTester tester, {bool reduceMotion = false}) async {
  final router = _ContractRouter();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
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
    testWidgets('$platform controller keeps the 160ms entry and exit durations', (tester) async {
      final router = await _pumpRouter(tester);
      final result = router.push<int>(const PageRouteInfo<void>('Detail'));
      await tester.pump();
      await tester.pump();
      final detail = router.builtRoutes['Detail']!;
      await tester.pump(const Duration(milliseconds: 80));
      expect(detail.animation!.value, closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 81));
      expect(detail.animation!.isCompleted, isTrue);
      expect(detail.transitionDuration, PrismDurations.fast);
      expect(detail.reverseTransitionDuration, PrismDurations.fast);

      await router.maybePop<int>(42);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(detail.animation!.value, closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 81));
      expect(await result, 42);
      expect(router.current.name, 'Grid');
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
  }
}
