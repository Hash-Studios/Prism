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
class _HistoryGuardRouter extends AppRouter {
  _HistoryGuardRouter({this.includeChildren = false});

  final bool includeChildren;

  @override
  List<AutoRoute> get routes => AppRouter().routes.map(_stubRoute).toList();

  AutoRoute _stubRoute(AutoRoute route) => route is RedirectRoute
      ? route
      : AutoRoute(
          path: route.path,
          page: PageInfo(
            route.page.name,
            builder: (_) => includeChildren && route.hasSubTree ? const AutoRouter() : Text(route.page.name),
          ),
          guards: route.guards,
          children: includeChildren ? route.children?.map(_stubRoute).toList() : null,
        );
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

  test('allows a guest to enter the dashboard on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final dashboard = AppRouter().routes.singleWhere((route) => route.path == '/dashboard');
    final guard = dashboard.guards.single as SignedInGuard;

    guard.onNavigation(resolver, router);

    verify(() => resolver.next()).called(1);
    verifyNever(() => resolver.next(false));
    verifyNever(() => router.pushPath<Object?>(any()));
  });

  for (final path in [
    '/ai',
    '/download-wallpaper',
    '/wallpaper-filter',
    '/choose-wallpaper',
    '/photo-preview',
    '/fav-walls',
    '/downloads',
    '/library',
    '/notifications',
    '/quick-tile-settings',
    '/auto-rotate',
    '/ios-shortcuts',
    '/wallpaper-position',
    '/live-wallpaper',
    '/rewards',
    '/dashboard/rewards',
  ]) {
    for (final cancel in [false, true]) {
      testWidgets('iOS guest action $path ${cancel ? 'cancels without continuation' : 'resumes after sign-in'}', (
        tester,
      ) async {
        final appRouter = _HistoryGuardRouter(includeChildren: true);
        final continuation = AuthNavigationContinuation.of(appRouter);
        addTearDown(continuation.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
        await tester.pumpAndSettle();
        unawaited(appRouter.replaceAll([AboutRoute()]));
        await tester.pumpAndSettle();

        unawaited(appRouter.pushPath(path));
        await tester.pumpAndSettle();
        expect(appRouter.current.name, OnboardingV2ShellRoute.name);
        final outcome = continuation.pendingNavigation!;
        if (cancel) {
          expect(await appRouter.maybePop(), isTrue);
          await tester.pumpAndSettle();
          expect(await outcome, isFalse);
          expect(appRouter.currentUrl, path.startsWith('/dashboard/') ? '/dashboard' : '/about');
        } else {
          app_state.prismUser.loggedIn = true;
          continuation.markBootstrapCompleted();
          unawaited(appRouter.replaceAll([const DashboardRoute()]));
          await tester.pumpAndSettle();
          expect(await outcome, isTrue);
          expect(appRouter.currentUrl, path);
        }
        expect(continuation.pendingNavigation, isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }

    testWidgets('signed-in iOS opens action $path directly', (tester) async {
      app_state.prismUser.loggedIn = true;
      final appRouter = _HistoryGuardRouter(includeChildren: true);
      final continuation = AuthNavigationContinuation.of(appRouter);
      addTearDown(continuation.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
      await tester.pumpAndSettle();
      unawaited(appRouter.pushPath(path));
      await tester.pumpAndSettle();
      expect(appRouter.currentUrl, path);
      expect(continuation.pendingNavigation, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  for (final path in ['/settings', '/theme', '/premium', '/clock-preview', '/drops/week/preview/wall']) {
    testWidgets('iOS guest keeps passive browse/control route $path', (tester) async {
      final appRouter = _HistoryGuardRouter();
      final continuation = AuthNavigationContinuation.of(appRouter);
      addTearDown(continuation.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
      await tester.pumpAndSettle();
      unawaited(appRouter.pushPath(path));
      await tester.pumpAndSettle();
      expect(appRouter.currentUrl, path);
      expect(continuation.pendingNavigation, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  for (final path in [
    '/dashboard',
    '/gallery',
    '/wallpaper-detail',
    '/collection-view',
    '/mood/calm',
    '/user/artist',
    '/drops/this-week',
  ]) {
    for (final useNavigate in [false, true]) {
      testWidgets('Android guest defers ${useNavigate ? 'navigatePath' : 'pushPath'} $path until sign-in', (
        tester,
      ) async {
        final appRouter = _HistoryGuardRouter();
        final continuation = AuthNavigationContinuation.of(appRouter);
        addTearDown(continuation.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
        await tester.pumpAndSettle();

        if (useNavigate) {
          unawaited(appRouter.navigatePath(path));
        } else {
          unawaited(appRouter.pushPath(path));
        }
        await tester.pumpAndSettle();

        expect(appRouter.current.name, OnboardingV2ShellRoute.name);
        expect(appRouter.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), hasLength(1));
        final outcome = continuation.pendingNavigation!;
        app_state.prismUser.loggedIn = true;
        continuation.markBootstrapCompleted();
        unawaited(appRouter.replaceAll([const DashboardRoute()]));
        await tester.pumpAndSettle();

        expect(await outcome, isTrue);
        expect(appRouter.currentUrl, path);
        expect(continuation.pendingNavigation, isNull);
        expect(appRouter.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('$platform permits $path ${platform == TargetPlatform.iOS ? 'as a guest' : 'when signed in'}', (
        tester,
      ) async {
        app_state.prismUser.loggedIn = platform == TargetPlatform.android;
        final appRouter = _HistoryGuardRouter();
        final continuation = AuthNavigationContinuation.of(appRouter);
        addTearDown(continuation.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
        await tester.pumpAndSettle();

        unawaited(appRouter.pushPath(path));
        await tester.pumpAndSettle();

        expect(appRouter.currentUrl, path);
        expect(continuation.pendingNavigation, isNull);
      }, variant: TargetPlatformVariant({platform}));
    }
  }

  testWidgets('Android guest can reach startup, onboarding, about and not-found without an auth loop', (tester) async {
    final appRouter = _HistoryGuardRouter();
    final continuation = AuthNavigationContinuation.of(appRouter);
    addTearDown(continuation.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
    await tester.pumpAndSettle();
    for (final path in ['/', '/onboarding/v2', '/about', '/not-found']) {
      unawaited(appRouter.navigatePath(path));
      await tester.pumpAndSettle();
      expect(appRouter.current.path, path);
      expect(continuation.pendingNavigation, isNull);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final cancel in [false, true]) {
    testWidgets('Android nested browse ${cancel ? 'cancels' : 'resumes'} the exact child destination', (tester) async {
      final appRouter = _HistoryGuardRouter(includeChildren: true);
      final continuation = AuthNavigationContinuation.of(appRouter);
      addTearDown(continuation.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
      await tester.pumpAndSettle();

      unawaited(appRouter.replaceAll([AboutRoute()]));
      await tester.pumpAndSettle();
      unawaited(appRouter.pushPath('/dashboard/search/users'));
      await tester.pumpAndSettle();
      expect(appRouter.current.name, OnboardingV2ShellRoute.name);
      expect(find.text(UserSearchRoute.name), findsNothing);
      final outcome = continuation.pendingNavigation!;

      if (cancel) {
        expect(await appRouter.maybePop(), isTrue);
        await tester.pumpAndSettle();
        expect(continuation.pendingNavigation, isNull);
        expect(await outcome, isFalse);
      }
      app_state.prismUser.loggedIn = true;
      continuation.markBootstrapCompleted();
      unawaited(appRouter.replaceAll([const DashboardRoute()]));
      await tester.pumpAndSettle();

      expect(continuation.pendingNavigation, isNull);
      if (cancel) {
        expect(find.text(UserSearchRoute.name), findsNothing);
        expect(appRouter.currentUrl, '/dashboard');
      } else {
        expect(await outcome, isTrue);
        expect(appRouter.currentUrl, '/dashboard/search/users');
        expect(find.text(UserSearchRoute.name), findsOneWidget);
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('a cold nested deep link respects the guest policy on $platform', (tester) async {
      final appRouter = _HistoryGuardRouter(includeChildren: true);
      final continuation = AuthNavigationContinuation.of(appRouter);
      addTearDown(continuation.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: appRouter.config(deepLinkBuilder: (_) => const DeepLink.path('/dashboard/search/users')),
        ),
      );
      await tester.pumpAndSettle();

      if (platform == TargetPlatform.android) {
        expect(appRouter.current.name, OnboardingV2ShellRoute.name);
        expect(find.text(UserSearchRoute.name), findsNothing);
        expect(continuation.pendingNavigation, isNotNull);
      } else {
        expect(appRouter.currentUrl, '/dashboard/search/users');
        expect(find.text(UserSearchRoute.name), findsOneWidget);
        expect(continuation.pendingNavigation, isNull);
      }
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('keeps account-required routes behind the sign-in guard', (tester) async {
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
    // The sign-in opens after the current frame.
    await tester.pump();

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
