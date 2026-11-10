import 'dart:async';
import 'dart:io';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_catalog_resolver.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
import 'package:Prism/core/router/route_guards.dart';
import 'package:Prism/core/startup/session_ended_navigation.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
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

typedef _AccessRow = ({String route, Set<String> targets, String guard, String access});

List<_AccessRow> _accessTable() {
  final String doc = File('docs/features/deep-links.md').readAsStringSync();
  final String section = doc.split('\n## Access table\n')[1].split('\n## ').first;
  return <_AccessRow>[
    for (final String line in section.split('\n'))
      if (line.startsWith('| `/') || line.startsWith('| `*`'))
        () {
          final List<String> cells = line.split('|').map((cell) => cell.trim()).toList();
          return (
            route: cells[1].replaceAll('`', ''),
            targets: RegExp('`([^`]+)`').allMatches(cells[2]).map((m) => m[1]!).toSet(),
            guard: cells[4],
            access: cells[5],
          );
        }(),
  ];
}

/// The real guard of each route path: `admin`, `sign-in` or `open`.
Map<String, Set<String>> _routerGuards(List<AutoRoute> routes) {
  final Map<String, Set<String>> result = <String, Set<String>>{};
  final Map<String, String> redirects = <String, String>{};
  void visit(List<AutoRoute> routes, String prefix, List<AutoRouteGuard> inherited) {
    for (final AutoRoute route in routes) {
      final String path = _routePath(prefix, route.path);
      if (route is RedirectRoute) {
        redirects[path] = _routePath(prefix, route.redirectTo);
        continue;
      }
      final List<AutoRouteGuard> guards = <AutoRouteGuard>[...inherited, ...route.guards];
      final String kind = guards.any((g) => g is AdminGuard)
          ? 'admin'
          : guards.any((g) => g is SignedInGuard && !g.allowGuests)
          ? 'sign-in'
          : 'open';
      result.putIfAbsent(path, () => <String>{}).add(kind);
      visit(route.children ?? const [], path, guards);
    }
  }

  visit(routes, '', const []);
  for (final entry in redirects.entries) {
    result[entry.key] = result[entry.value]!;
  }
  return result;
}

String _routePath(String prefix, String path) => path.startsWith('/') || prefix.isEmpty
    ? path
    : path.isEmpty
    ? prefix
    : '$prefix/$path';

Map<String, String> _pagePaths(List<AutoRoute> routes, [String prefix = '']) => <String, String>{
  for (final route in routes)
    if (route is! RedirectRoute) ...{
      route.page.name: _routePath(prefix, route.path),
      ..._pagePaths(route.children ?? const [], _routePath(prefix, route.path)),
    },
};

void main() {
  group('Access table', () {
    const Map<String, String> guardKinds = <String, String>{
      'none': 'open',
      'guests on iOS': 'open',
      'prompt': 'open',
      'sign-in': 'sign-in',
      'admin': 'admin',
    };
    const Map<String, Set<String>> guardsOfAccess = <String, Set<String>>{
      'public': {'none', 'guests on iOS'},
      'account': {'sign-in', 'prompt'},
      'owner': {'sign-in'},
      'admin': {'admin'},
    };
    final List<_AccessRow> rows = _accessTable();

    test('wrapper and default child may share a path, but cannot disagree on access', () {
      final List<AutoRoute> routes = <AutoRoute>[
        AutoRoute(
          path: '/same',
          page: const PageInfo.emptyShell('WrapperRoute'),
          children: [
            AutoRoute(path: '', page: const PageInfo.emptyShell('DefaultRoute'), guards: const [SignedInGuard()]),
          ],
        ),
      ];

      expect(_routerGuards(routes)['/same'], {'open', 'sign-in'});
      expect(_routerGuards(AppRouter().routes)['/dashboard/search'], {'open'});
    });

    test('every route has one Access rule that agrees with its guard', () {
      final Map<String, Set<String>> router = _routerGuards(AppRouter().routes);
      expect(rows.map((row) => row.route).toList()..sort(), router.keys.toList()..sort());
      expect(
        router.entries.where((entry) => entry.value.length != 1).map((entry) => entry.key),
        isEmpty,
        reason: 'Routes sharing a URL must agree on its access rule.',
      );
      for (final _AccessRow row in rows) {
        expect(guardsOfAccess[row.access], contains(row.guard), reason: row.route);
        expect(router[row.route], {guardKinds[row.guard]}, reason: row.route);
      }
    });

    test('every deep link target has one Access rule', () {
      final List<String> targets = rows.expand((row) => row.targets).toList()..sort();
      expect(targets, DeepLinkPageTarget.values.map((target) => target.name).toList()..sort());
    });

    test('target rules describe the resolved page, including explicit fallback destinations', () async {
      final paths = _pagePaths(AppRouter().routes);
      const profile = PublicProfileEntity(
        id: 'alice-id',
        name: 'Alice',
        email: '',
        username: 'alice',
        profilePhoto: '',
        bio: '',
        links: {},
        coverPhoto: '',
      );
      const wallpaper = PrismFeedItem(
        id: 'wall1',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'wall1',
            source: WallpaperSource.prism,
            fullUrl: 'https://prismwalls.com/api/ai/assets/ai/studio/wall.jpg',
            thumbnailUrl: 'https://prismwalls.com/api/ai/assets/ai/studio/thumb_wall.jpg',
          ),
        ),
      );
      addTearDown(() => DailyMomentConfig.enabledOverride = null);
      for (final enabled in [false, true]) {
        DailyMomentConfig.enabledOverride = enabled;
        for (final signedIn in [false, true]) {
          app_state.prismUser = createGuestPrismUser()..loggedIn = signedIn;
          for (final example in DeepLinkRouteCatalog.examples) {
            final target = example.target;
            final rule = rows.singleWhere((row) => row.targets.contains(target.name));
            final route = await routeForPageLink(
              PageLinkIntent(path: example.uri, rawUri: example.uri),
              profileLookup: (_) async => profile,
              wallpaperLookup: ({required String wallId, required WallpaperSource source}) async => wallpaper,
            );
            expect(route, isNotNull, reason: example.uri);
            final destination = route!.flattened.last;
            final String expectedPath = switch (target) {
              DeepLinkPageTarget.splash => '/dashboard',
              DeepLinkPageTarget.wallpaperFilterInput => '/choose-wallpaper',
              DeepLinkPageTarget.downloadWallpaperInput ||
              DeepLinkPageTarget.wallpaperPositionInput ||
              DeepLinkPageTarget.liveWallpaperInput =>
                example.uri.contains('wallpaperId=') || example.uri.contains('/wallpaper/')
                    ? '/wallpaper-detail'
                    : '/choose-wallpaper',
              DeepLinkPageTarget.followers || DeepLinkPageTarget.following when !signedIn => '/user/:identifier',
              DeepLinkPageTarget.dailyMoment => enabled ? '/daily-moment' : '/rewards',
              DeepLinkPageTarget.dailyChest || DeepLinkPageTarget.spinWheel when enabled => '/daily-moment',
              _ => rule.route,
            };
            expect(paths[destination.routeName], expectedPath, reason: '${example.uri}, signedIn=$signedIn');
          }
        }
      }
    });

    for (final _AccessRow row in rows) {
      final String path = row.route == '*' ? '/unknown-destination' : row.route.replaceAll(RegExp(':[A-Za-z]+'), 'x');
      final String expectedPath = switch (row.route) {
        '/paywall' => '/premium',
        '/coin-transactions' || '/streak' => '/rewards',
        '/dashboard/streak' => '/dashboard/rewards',
        '*' => '/not-found',
        _ => path,
      };
      for (final TargetPlatform platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final bool opens = platform == TargetPlatform.android
            ? const {'/', '/onboarding/v2', '/about', '/not-found'}.contains(expectedPath)
            : guardKinds[row.guard] == 'open';
        testWidgets('a signed-out $platform user ${opens ? 'opens' : 'gets sign-in before'} ${row.route}', (
          tester,
        ) async {
          app_state.prismUser = createGuestPrismUser();
          final appRouter = _HistoryGuardRouter(includeChildren: true);
          final continuation = AuthNavigationContinuation.of(appRouter);
          addTearDown(continuation.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: appRouter.config(
                deepLinkBuilder: platform == TargetPlatform.android ? (_) => DeepLink.path(path) : null,
              ),
            ),
          );
          if (platform == TargetPlatform.iOS) {
            await tester.pumpAndSettle();
            unawaited(appRouter.replaceAll([AboutRoute()]));
            await tester.pumpAndSettle();
            unawaited(appRouter.pushPath(path));
          }
          await tester.pumpAndSettle();

          if (opens) {
            expect(appRouter.currentUrl, startsWith(expectedPath));
            expect(continuation.pendingNavigation, isNull);
          } else {
            expect(appRouter.current.name, OnboardingV2ShellRoute.name);
            expect(continuation.pendingNavigation, isNotNull);
          }
          if (platform == TargetPlatform.android) {
            expect(
              appRouter.stackData.map((route) => route.name).toSet().difference({
                SplashWidgetRoute.name,
                OnboardingV2ShellRoute.name,
                AboutRoute.name,
                NotFoundRoute.name,
              }),
              isEmpty,
              reason: 'A cold guest link must not leave a protected page below sign-in.',
            );
          }
        }, variant: TargetPlatformVariant({platform}));
      }
    }
  });

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

  for (final relation in ['followers', 'following']) {
    testWidgets('Android guest relation resolver fallback cannot bypass sign-in: $relation', (tester) async {
      final appRouter = _HistoryGuardRouter();
      final continuation = AuthNavigationContinuation.of(appRouter);
      addTearDown(continuation.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
      await tester.pumpAndSettle();
      final path = '/user/alice/$relation';
      final route = await routeForPageLink(
        PageLinkIntent(path: path, rawUri: path),
        profileLookup: (_) async => throw StateError('Guest must not read profiles'),
      );
      expect(route, isA<ProfileRoute>());

      unawaited(appRouter.push(route!));
      await tester.pumpAndSettle();

      expect(appRouter.current.name, OnboardingV2ShellRoute.name);
      expect(find.text(ProfileRoute.name), findsNothing);
      expect(continuation.pendingNavigation, isNotNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('Android sign-in cancellation allows retry without reviving the cancelled path', (tester) async {
    final appRouter = _HistoryGuardRouter();
    final continuation = AuthNavigationContinuation.of(appRouter);
    addTearDown(continuation.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
    await tester.pumpAndSettle();
    unawaited(appRouter.replaceAll([AboutRoute()]));
    await tester.pumpAndSettle();
    unawaited(appRouter.pushPath('/coin-history'));
    await tester.pumpAndSettle();
    final cancelled = continuation.pendingNavigation!;
    expect(await appRouter.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(await cancelled, isFalse);
    expect(continuation.pendingNavigation, isNull);

    unawaited(appRouter.pushPath('/settings'));
    await tester.pumpAndSettle();
    expect(appRouter.current.name, OnboardingV2ShellRoute.name);
    final retried = continuation.pendingNavigation!;
    app_state.prismUser.loggedIn = true;
    continuation.markBootstrapCompleted();
    unawaited(appRouter.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();

    expect(await retried, isTrue);
    expect(appRouter.currentUrl, '/settings');
    expect(appRouter.stackData.where((route) => route.name == CoinHistoryRoute.name), isEmpty);
    expect(continuation.pendingNavigation, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android sign-out clears the stack and stale protected paths require sign-in again', (tester) async {
    app_state.prismUser.loggedIn = true;
    final appRouter = _HistoryGuardRouter();
    final continuation = AuthNavigationContinuation.of(appRouter);
    addTearDown(continuation.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
    await tester.pumpAndSettle();
    unawaited(appRouter.pushPath('/coin-history'));
    await tester.pumpAndSettle();
    expect(appRouter.current.name, CoinHistoryRoute.name);

    unawaited(
      handleSessionEndedNavigation(
        router: appRouter,
        signOut: () async {
          app_state.prismUser = createGuestPrismUser();
          return true;
        },
        isMounted: () => true,
        showGuestPrompt: () async => fail('Android must not enter guest mode'),
      ),
    );
    await tester.pumpAndSettle();
    expect(appRouter.stackData.map((route) => route.name), [OnboardingV2ShellRoute.name]);
    expect(continuation.pendingNavigation, isNull);

    unawaited(appRouter.pushPath('/coin-history'));
    await tester.pumpAndSettle();
    expect(appRouter.current.name, OnboardingV2ShellRoute.name);
    expect(find.text(CoinHistoryRoute.name), findsNothing);
    expect(appRouter.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), hasLength(1));
    expect(continuation.pendingNavigation, isNotNull);
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
