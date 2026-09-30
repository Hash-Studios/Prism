import 'package:Prism/core/router/app_router.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

/// An [AppRouter] with the real route names and stub pages, so tests can drive startup without the real screens.
class StubAppRouter extends AppRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(path: '/', page: _stub(SplashWidgetRoute.name)),
    AutoRoute(path: '/onboarding/v2', page: _stub(OnboardingV2ShellRoute.name)),
    AutoRoute(path: '/dashboard', page: _stub(DashboardRoute.name)),
    AutoRoute(path: '/downloads', page: _stub(DownloadRoute.name)),
  ];

  static PageInfo _stub(String name) => PageInfo(name, builder: (_) => Text(name));
}
