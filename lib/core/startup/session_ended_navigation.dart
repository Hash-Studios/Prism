import 'package:Prism/core/auth/guest_browsing_policy.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';

Future<void> handleSessionEndedNavigation({
  required StackRouter router,
  required Future<bool> Function() signOut,
  required bool Function() isMounted,
  required Future<void> Function() showGuestPrompt,
}) async {
  AuthNavigationContinuation.of(router).cancel();
  await signOut();
  // A false result can mean a newer sign-in took ownership, or Firebase sign-out
  // failed after local cleanup. Only a still-signed-in session keeps its routes.
  if (!isMounted() || app_state.prismUser.loggedIn) return;
  if (!guestBrowsingAllowed) {
    await router.replaceAll([OnboardingV2ShellRoute()]);
    return;
  }
  await showGuestPrompt();
}
