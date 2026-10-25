import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/router/route_guards.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNavigationResolver extends Mock implements NavigationResolver {}

class _MockStackRouter extends Mock implements StackRouter {}

class _MockRootRouter extends Mock implements RootStackRouter {}

// Keep production route matching and guards, but avoid mounting feature dependencies.
class _HistoryGuardRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => AppRouter().routes
      .where((route) => ['/', '/dashboard', '/onboarding/v2', '/coin-history'].contains(route.path))
      .map(
        (route) => AutoRoute(
          path: route.path,
          page: PageInfo(route.page.name, builder: (_) => Text(route.page.name)),
          guards: route.guards,
        ),
      )
      .toList();
}

void main() {
  late _MockNavigationResolver resolver;
  late _MockStackRouter router;

  setUp(() {
    resolver = _MockNavigationResolver();
    router = _MockStackRouter();
    app_state.prismUser = createGuestPrismUser();
    when(() => resolver.next()).thenReturn(null);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    app_state.prismUser = createGuestPrismUser();
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final useNavigate in [false, true]) {
      testWidgets('actual history guard defers ${useNavigate ? 'navigate' : 'push'} entry on $platform', (
        tester,
      ) async {
        final historyRouter = _HistoryGuardRouter();
        final continuation = AuthNavigationContinuation.of(historyRouter);
        addTearDown(continuation.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: historyRouter.config()));
        await tester.pumpAndSettle();
        unawaited(historyRouter.replaceAll([const DashboardRoute()]));
        await tester.pumpAndSettle();

        if (useNavigate) {
          unawaited(historyRouter.navigate(const CoinHistoryRoute()));
        } else {
          unawaited(historyRouter.push(const CoinHistoryRoute()));
        }
        await tester.pumpAndSettle();

        expect(historyRouter.current.name, OnboardingV2ShellRoute.name);
        expect(find.text(CoinHistoryRoute.name), findsNothing);
        final outcome = continuation.pendingNavigation!;
        app_state.prismUser.loggedIn = true;
        unawaited(historyRouter.replaceAll([const SplashWidgetRoute()]));
        await tester.pumpAndSettle();
        unawaited(historyRouter.replaceAll([const DashboardRoute()]));
        await tester.pumpAndSettle();
        expect(historyRouter.current.name, DashboardRoute.name);

        continuation.markBootstrapCompleted();
        await tester.pumpAndSettle();
        expect(await outcome, isTrue);
        expect(historyRouter.current.name, CoinHistoryRoute.name);
        expect(find.text(CoinHistoryRoute.name), findsOneWidget);
        historyRouter.notifyAll();
        await tester.pumpAndSettle();
        expect(historyRouter.stackData.where((route) => route.name == CoinHistoryRoute.name), hasLength(1));
        expect(continuation.pendingNavigation, isNull);
      }, variant: TargetPlatformVariant({platform}));
    }

    testWidgets('actual history guard allows signed-in direct entry on $platform', (tester) async {
      app_state.prismUser.loggedIn = true;
      final historyRouter = _HistoryGuardRouter();
      final continuation = AuthNavigationContinuation.of(historyRouter);
      addTearDown(continuation.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: historyRouter.config()));
      await tester.pumpAndSettle();
      unawaited(historyRouter.push(const CoinHistoryRoute()));
      await tester.pumpAndSettle();

      expect(historyRouter.current.name, CoinHistoryRoute.name);
      expect(find.text(CoinHistoryRoute.name), findsOneWidget);
      expect(historyRouter.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
      expect(continuation.pendingNavigation, isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  test('allows a guest to enter the dashboard on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final dashboard = AppRouter().routes.singleWhere((route) => route.path == '/dashboard');
    final guard = dashboard.guards.single as SignedInGuard;

    guard.onNavigation(resolver, router);

    verify(() => resolver.next()).called(1);
    verifyNever(() => resolver.next(false));
    verifyNever(() => router.pushPath<Object?>(any()));
  });

  test('keeps account-required routes behind the sign-in guard', () {
    final root = _MockRootRouter();
    when(() => router.root).thenReturn(root);
    when(() => router.isRoot).thenReturn(true);
    when(() => root.root).thenReturn(root);
    when(() => root.stackData).thenReturn([]);
    when(() => resolver.route).thenReturn(AppRouter().matcher.matchByRoute(const ShopRoute())!);
    when(() => resolver.pendingRoutes).thenReturn([]);
    when(
      () => root.pushPath<Object?>('/onboarding/v2', onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) => Completer<Object?>().future);
    addTearDown(AuthNavigationContinuation.of(root).dispose);

    const SignedInGuard().onNavigation(resolver, router);

    expect(AuthNavigationContinuation.of(root).pendingNavigation, isNotNull);
    verify(() => root.pushPath<Object?>('/onboarding/v2', onFailure: any(named: 'onFailure'))).called(1);
    verify(() => resolver.next(false)).called(1);
  });

  test('allows a signed-in user without redirecting', () {
    app_state.prismUser.loggedIn = true;

    const SignedInGuard().onNavigation(resolver, router);

    verify(() => resolver.next()).called(1);
    verifyNever(() => router.pushPath<Object?>(any()));
  });

  test('a signed-in non-admin stays denied without starting sign-in', () {
    app_state.prismUser.loggedIn = true;
    when(() => router.pushPath<Object?>('/not-found')).thenAnswer((_) async => null);

    const AdminGuard().onNavigation(resolver, router);

    verify(() => resolver.next(false)).called(1);
    verify(() => router.pushPath<Object?>('/not-found')).called(1);
    verifyNever(() => router.pushPath<Object?>('/onboarding/v2'));
  });
}
