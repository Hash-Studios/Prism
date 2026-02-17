import 'package:Prism/core/router/app_navigator_host.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

class AppRouter {
  AppRouter({required this.initialRouteName})
      : _router = RootStackRouter.build(
          routes: [
            NamedRouteDef(
              name: _appShellRouteName,
              path: '/',
              builder: (context, data) => AppNavigatorHost(
                initialRouteName: initialRouteName,
              ),
            ),
          ],
        );

  static const String _appShellRouteName = 'AppShellRoute';

  final String initialRouteName;
  final RootStackRouter _router;

  RouterConfig<Object> config() {
    return _router.config(
      includePrefixMatches: true,
    );
  }
}
