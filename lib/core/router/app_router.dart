import 'package:Prism/core/router/legacy_navigator_host.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

class AppRouter {
  AppRouter({required this.initialLegacyRoute})
      : _router = RootStackRouter.build(
          defaultRouteType: const RouteType.material(),
          routes: [
            NamedRouteDef(
              name: _appShellRouteName,
              path: '/',
              builder: (context, data) => LegacyNavigatorHost(
                initialRouteName: initialLegacyRoute,
              ),
            ),
          ],
        );

  static const String _appShellRouteName = 'AppShellRoute';

  final String initialLegacyRoute;
  final RootStackRouter _router;

  RouterConfig<Object> config() {
    return _router.config(
      includePrefixMatches: true,
    );
  }
}
