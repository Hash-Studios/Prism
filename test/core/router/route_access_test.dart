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
  @override
  List<AutoRoute> get routes => AppRouter().routes.map(_stub).toList();

  AutoRoute _stub(AutoRoute route) => route is RedirectRoute
      ? route
      : AutoRoute(
          path: route.path,
          page: PageInfo(
            route.page.name,
            builder: (_) => route.hasSubTree ? const AutoRouter() : Text(route.page.name),
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
      ..._pageRoutes(route.children?.routes ?? const <AutoRoute>[], _join(parent, route.path)),
    ],
];

String _join(String parent, String path) {
  final String joined = path.startsWith('/') ? path : (path.isEmpty ? parent : '$parent/$path');
  return joined.replaceAllMapped(RegExp(r':\w+'), (_) => 'x');
}

void main() {
  final List<_Route> routes = _pageRoutes(AppRouter().routes);

  tearDown(() => app_state.prismUser = createGuestPrismUser());

  test('every route has an access rule, and every rule names a route', () {
    final Set<String> names = routes.map((route) => route.name).toSet();

    expect(names.difference(routeAccess.keys.toSet()), isEmpty, reason: 'Add these routes to routeAccess');
    expect(routeAccess.keys.toSet().difference(names), isEmpty, reason: 'Remove these stale rows');
  });

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
      final RouteAccess access = routeAccess[route.name]!;
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
