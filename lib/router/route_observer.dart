import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:prism/services/logger.dart';

class AppRouteObserver extends AutoRouterObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    logger.i('New route pushed: ${route.settings.name}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    logger.w('Route popped: ${route.settings.name}');
  }
}
