import 'package:Prism/core/auth/guest_browsing_policy.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';

class SignedInGuard extends AutoRouteGuard {
  const SignedInGuard({this.allowGuests = false});

  final bool allowGuests;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (app_state.prismUser.loggedIn || (allowGuests && guestBrowsingAllowed)) {
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

class PlatformAccountGuard extends AutoRouteGuard {
  const PlatformAccountGuard();

  static const _publicRoutes = {'SplashWidgetRoute', 'OnboardingV2ShellRoute', 'AboutRoute', 'NotFoundRoute'};

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (guestBrowsingAllowed || _publicRoutes.contains(resolver.route.name)) {
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
