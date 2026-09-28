import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';

class SignedInGuard extends AutoRouteGuard {
  const SignedInGuard({this.allowIosGuests = false});

  /// iOS lets people browse without an account (App Review 5.1.1(v)); Android always requires sign-in.
  final bool allowIosGuests;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (app_state.prismUser.loggedIn || (allowIosGuests && defaultTargetPlatform == TargetPlatform.iOS)) {
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
