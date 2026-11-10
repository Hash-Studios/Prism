import 'package:Prism/core/auth/guest_browsing_policy.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/router/route_access.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';

class SignedInGuard extends AutoRouteGuard {
  const SignedInGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (app_state.prismUser.loggedIn) {
      resolver.next();
      return;
    }
    final continuation = AuthNavigationContinuation.of(router);
    if (!continuation.isResuming && !continuation.isCancelled(resolver.route)) {
      continuation.defer(resolver, router: router);
    }
    resolver.next(false);
  }
}

/// Applies [routeAccess] to guarded stack navigation. Tab navigation may bypass guards; guest handling there is page-level.
/// Android has no guests, so its public routes need an account too.
class PlatformAccountGuard extends AutoRouteGuard {
  const PlatformAccountGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final bool guestCanView = switch (routeAccess[resolver.route.name] ?? RouteAccess.account) {
      RouteAccess.open => true,
      RouteAccess.public => guestBrowsingAllowed,
      RouteAccess.account || RouteAccess.owner || RouteAccess.admin => false,
    };
    if (guestCanView) {
      resolver.next();
      return;
    }
    const SignedInGuard().onNavigation(resolver, router);
  }
}

class AdminGuard extends AutoRouteGuard {
  const AdminGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (!app_state.prismUser.loggedIn) {
      const SignedInGuard().onNavigation(resolver, router);
      return;
    }
    if (app_state.isAdminUser()) {
      resolver.next();
      return;
    }
    router.pushPath('/not-found');
    resolver.next(false);
  }
}
