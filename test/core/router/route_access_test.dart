import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/router/route_access.dart';
import 'package:Prism/core/router/route_guards.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production paths and guards, with each page swapped for its name so no feature dependency mounts.
class _StubPagesRouter extends AppRouter {
  _StubPagesRouter({this.includeUnclassifiedRoute = false, this.useTabs = false});

  final bool includeUnclassifiedRoute;
  final bool useTabs;

  @override
  List<AutoRoute> get routes => [
    if (includeUnclassifiedRoute)
      AutoRoute(
        path: '/unclassified',
        page: PageInfo('UnclassifiedRoute', builder: (_) => const Text('unclassified')),
      ),
    ...AppRouter().routes.map(_stub),
  ];

  AutoRoute _stub(AutoRoute route) => route is RedirectRoute
      ? route
      : AutoRoute(
          path: route.path,
          page: PageInfo(
            route.page.name,
            builder: (_) {
              if (useTabs && route.page.name == DashboardRoute.name) {
                return AutoTabsRouter(
                  routes: const [HomeTabRoute(), SearchTabRoute(), RewardsTabRoute(), CollectionTabRoute()],
                  builder: (_, child) => Column(
                    children: [
                      Text(route.page.name),
                      Expanded(child: child),
                    ],
                  ),
                );
              }
              return route.hasSubTree ? const AutoRouter() : Text(route.page.name);
            },
          ),
          guards: route.guards,
          children: route.children?.map(_stub).toList(),
        );
}

final class _Route {
  const _Route(this.name, this.path, this.guards);

  final String name;
  final String path;
  final List<AutoRouteGuard> guards;
}

/// Every page route with a concrete path. Path parameters get a sample id.
List<_Route> _pageRoutes(List<AutoRoute> routes, [String parent = '']) => [
  for (final AutoRoute route in routes)
    if (route is! RedirectRoute) ...[
      _Route(route.page.name, _join(parent, route.path), route.guards),
      ..._pageRoutes(route.children ?? const <AutoRoute>[], _join(parent, route.path)),
    ],
];

String _join(String parent, String path) {
  final String joined = path.startsWith('/') ? path : (path.isEmpty ? parent : '$parent/$path');
  return joined.replaceAllMapped(RegExp(r':\w+'), (_) => 'x');
}

void main() {
  final List<_Route> routes = _pageRoutes(AppRouter().routes);
  const Map<String, RouteAccess> expectedAccess = <String, RouteAccess>{
    'SplashWidgetRoute': RouteAccess.open,
    'OnboardingV2ShellRoute': RouteAccess.open,
    'AboutRoute': RouteAccess.open,
    'NotFoundRoute': RouteAccess.open,

    'DashboardRoute': RouteAccess.public,
    'HomeTabRoute': RouteAccess.public,
    'SearchTabRoute': RouteAccess.public,
    'SearchRoute': RouteAccess.public,
    'CollectionTabRoute': RouteAccess.public,
    'WallpaperDetailRoute': RouteAccess.public,
    'WotdArchiveRoute': RouteAccess.public,
    'ShareInRoute': RouteAccess.public,
    'PremiumRoute': RouteAccess.public,
    'ClockPreviewRoute': RouteAccess.public,
    'SettingsRoute': RouteAccess.public,
    'LayoutSettingsRoute': RouteAccess.public,
    'ThemeViewRoute': RouteAccess.public,
    'CollectionViewRoute': RouteAccess.public,
    'MoodRoute': RouteAccess.public,
    'EditorsChoiceRoute': RouteAccess.public,
    'GalleryRoute': RouteAccess.public,
    'WallRequestsRoute': RouteAccess.public,
    'WeeklyChallengeRoute': RouteAccess.public,
    'DropsRoute': RouteAccess.public,
    'DropDetailRoute': RouteAccess.public,
    'DropPreviewRoute': RouteAccess.public,
    'UserSearchRoute': RouteAccess.public,
    'ProfileRoute': RouteAccess.public,

    'FollowersRoute': RouteAccess.account,
    'FollowingListRoute': RouteAccess.account,
    'CreatorsRoute': RouteAccess.account,
    'FoldersDiscoverRoute': RouteAccess.account,
    'FolderInviteRoute': RouteAccess.account,
    'AiTabRoute': RouteAccess.account,
    'DownloadWallpaperRoute': RouteAccess.account,
    'WallpaperFilterRoute': RouteAccess.account,
    'DeepLinkInputRoute': RouteAccess.account,
    'ReviewPhotoPreviewRoute': RouteAccess.account,
    'UploadWallRoute': RouteAccess.account,
    'QuickTileSettingsRoute': RouteAccess.account,
    'AutoRotateRoute': RouteAccess.account,
    'IosShortcutsGuideRoute': RouteAccess.account,
    'WallpaperPositionRoute': RouteAccess.account,
    'LiveWallpaperRoute': RouteAccess.account,
    'DailyMomentRoute': RouteAccess.account,
    'DailyChestRoute': RouteAccess.account,
    'SpinWheelRoute': RouteAccess.account,
    'ShopRoute': RouteAccess.account,
    'LeaderboardRoute': RouteAccess.account,
    'DrawRoute': RouteAccess.account,

    'FolderRoute': RouteAccess.owner,
    'RewardsTabRoute': RouteAccess.owner,
    'RewardsRoute': RouteAccess.owner,
    'CoinHistoryRoute': RouteAccess.owner,
    'EditProfilePanelRoute': RouteAccess.owner,
    'SharePrismRoute': RouteAccess.owner,
    'BlockedAccountsRoute': RouteAccess.owner,
    'FavouriteWallpaperRoute': RouteAccess.owner,
    'DownloadRoute': RouteAccess.owner,
    'LibraryRoute': RouteAccess.owner,
    'EditWallRoute': RouteAccess.owner,
    'CreatorStatsRoute': RouteAccess.owner,
    'ReviewRoute': RouteAccess.owner,
    'NotificationRoute': RouteAccess.owner,
    'PrismWrappedRoute': RouteAccess.owner,

    'AdminReviewRoute': RouteAccess.admin,
    'SwipeReviewRoute': RouteAccess.admin,
    'FullScreenImageRoute': RouteAccess.admin,
    'FirestoreTelemetryRoute': RouteAccess.admin,
    'PromoCodesAdminRoute': RouteAccess.admin,
    'DebugPanelRoute': RouteAccess.admin,
  };

  tearDown(() => app_state.prismUser = createGuestPrismUser());

  test('every route has an access rule, and every rule names a route', () {
    final Set<String> names = routes.map((route) => route.name).toSet();

    expect(names.difference(routeAccess.keys.toSet()), isEmpty, reason: 'Add these routes to routeAccess');
    expect(routeAccess.keys.toSet().difference(names), isEmpty, reason: 'Remove these stale rows');
  });

  test('each route keeps its independently specified access classification', () {
    expect(routeAccess, expectedAccess);
  });

  test('the global access guard is installed once and route-local guards are admin-only', () {
    expect(AppRouter().guards, hasLength(1));
    expect(AppRouter().guards.single, isA<PlatformAccountGuard>());
    for (final _Route route in routes) {
      expect(
        route.guards.where((guard) => guard is! AdminGuard),
        isEmpty,
        reason: '${route.name} must rely on the global platform access guard',
      );
    }
  });

  testWidgets('an unclassified route fails closed for a signed-out user', (tester) async {
    final appRouter = _StubPagesRouter(includeUnclassifiedRoute: true);
    final continuation = AuthNavigationContinuation.of(appRouter);
    addTearDown(continuation.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
    await tester.pumpAndSettle();

    unawaited(appRouter.pushPath('/unclassified'));
    await tester.pumpAndSettle();

    expect(appRouter.current.name, OnboardingV2ShellRoute.name);
    expect(find.text('unclassified'), findsNothing);
    expect(continuation.pendingNavigation, isNotNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android signed-out users cannot mount the tabs dashboard', (tester) async {
    final appRouter = _StubPagesRouter(useTabs: true);
    final continuation = AuthNavigationContinuation.of(appRouter);
    addTearDown(continuation.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
    await tester.pumpAndSettle();

    unawaited(appRouter.pushPath('/dashboard'));
    await tester.pumpAndSettle();

    expect(appRouter.current.name, OnboardingV2ShellRoute.name);
    expect(find.text(DashboardRoute.name), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS global access leaves the rewards tab to its page-level sign-in prompt', (tester) async {
    final appRouter = _StubPagesRouter(useTabs: true);
    final continuation = AuthNavigationContinuation.of(appRouter);
    addTearDown(continuation.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
    await tester.pumpAndSettle();

    unawaited(appRouter.pushPath('/dashboard'));
    await tester.pumpAndSettle();
    appRouter.innerRouterOf<TabsRouter>(DashboardRoute.name)!.setActiveIndex(2);
    await tester.pumpAndSettle();

    // RewardsPage owns the guest SignInPrompt; the global route guard must not replace the page.
    expect(find.text(RewardsTabRoute.name), findsOneWidget);
    expect(find.text(OnboardingV2ShellRoute.name), findsNothing);
    expect(continuation.pendingNavigation, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('admin rows keep their AdminGuard, and no route has its own sign-in guard', () {
    for (final _Route route in routes) {
      expect(
        route.guards.whereType<AdminGuard>().isNotEmpty,
        routeAccess[route.name] == RouteAccess.admin,
        reason: route.name,
      );
      expect(route.guards.whereType<SignedInGuard>(), isEmpty, reason: route.name);
    }
  });

  test('the folder and creator routes stay signed-in until the rules let guests read them', () {
    expect(routeAccess[FolderRoute.name], RouteAccess.owner);
    expect(routeAccess[FoldersDiscoverRoute.name], RouteAccess.account);
    expect(routeAccess[CreatorsRoute.name], RouteAccess.account);
    expect(routeAccess[FolderInviteRoute.name], RouteAccess.account);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final _Route route in routes) {
      final RouteAccess access = expectedAccess[route.name]!;
      final bool guestCanView =
          access == RouteAccess.open || (access == RouteAccess.public && platform == TargetPlatform.iOS);
      final String who = platform == TargetPlatform.iOS ? 'iOS guest' : 'signed-out Android user';

      testWidgets('$who ${guestCanView ? 'opens' : 'is sent to sign-in for'} ${route.path} (${access.name})', (
        tester,
      ) async {
        final appRouter = _StubPagesRouter();
        final continuation = AuthNavigationContinuation.of(appRouter);
        addTearDown(continuation.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.config()));
        await tester.pumpAndSettle();

        unawaited(appRouter.pushPath(route.path));
        await tester.pumpAndSettle();

        if (guestCanView) {
          expect(appRouter.currentUrl, route.path);
          expect(continuation.pendingNavigation, isNull);
        } else {
          expect(appRouter.current.name, OnboardingV2ShellRoute.name);
          expect(continuation.pendingNavigation, isNotNull);
          expect(find.text(route.name), findsNothing);
        }
      }, variant: TargetPlatformVariant.only(platform));
    }
  }
}
