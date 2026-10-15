import 'dart:async';

import 'package:Prism/core/router/app_router.dart';
import 'package:auto_route/auto_route.dart';

/// True while the splash or onboarding is in [router]'s stack. Both call `replaceAll` when they finish, which drops a
/// route pushed before that.
bool isStartingUp(StackRouter router) =>
    !router.hasEntries ||
    router.stackData.any((route) => route.name == SplashWidgetRoute.name || route.name == OnboardingV2ShellRoute.name);

/// Completes with true when startup ends in [router], however long onboarding takes. It re-checks on each router
/// change, so there is no time limit and no polling. It completes with false when [isMounted] is false at a change.
Future<bool> waitForStartupEnd(StackRouter router, {required bool Function() isMounted}) {
  if (!isStartingUp(router)) return Future<bool>.value(isMounted());
  final Completer<bool> done = Completer<bool>();
  void onChanged() {
    if (isMounted() && isStartingUp(router)) return;
    router.removeListener(onChanged);
    done.complete(isMounted());
  }

  router.addListener(onChanged);
  return done.future;
}
