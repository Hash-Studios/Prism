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
    router.pushPath('/onboarding/v2');
    resolver.next(false);
  }
}

class AdminGuard extends AutoRouteGuard {
  const AdminGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (app_state.isAdminUser()) {
      resolver.next();
      return;
    }
    router.pushPath('/not-found');
    resolver.next(false);
  }
}
