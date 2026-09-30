import 'package:Prism/core/router/app_router.dart';
import 'package:auto_route/auto_route.dart';

/// True while the splash or onboarding is in [router]'s stack. Both call `replaceAll` when they finish, which drops a
/// route pushed before that.
bool isStartingUp(StackRouter router) =>
    !router.hasEntries ||
    router.stackData.any((route) => route.name == SplashWidgetRoute.name || route.name == OnboardingV2ShellRoute.name);

Future<bool> waitForPushTapStartup({required bool Function() isMounted, required bool Function() isReady}) async {
  // ponytail: polls every 100 ms and gives up after 30 s (for example on the obsolete-version screen).
  for (int i = 0; i < 300 && isMounted() && !isReady(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return isMounted() && isReady();
}
