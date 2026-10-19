import 'package:Prism/core/router/app_router.dart';
import 'package:auto_route/auto_route.dart';

/// True while the splash or onboarding is in [router]'s stack. Both call `replaceAll` when they finish, which drops a
/// route pushed before that.
bool isStartingUp(StackRouter router) =>
    !router.hasEntries ||
    router.stackData.any((route) => route.name == SplashWidgetRoute.name || route.name == OnboardingV2ShellRoute.name);
