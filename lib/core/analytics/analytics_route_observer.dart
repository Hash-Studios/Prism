import 'dart:async';

import 'package:flutter/widgets.dart';

typedef AnalyticsScreenViewCallback =
    Future<void> Function({required String screenName, String? screenClass, Map<String, Object?>? parameters});

class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver({required this.onScreenView});

  final AnalyticsScreenViewCallback onScreenView;

  String? _lastTrackedRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trackRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _trackRoute(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trackRoute(previousRoute);
    super.didPop(route, previousRoute);
  }

  void _trackRoute(Route<dynamic>? route) {
    final String? routeName = _resolveRouteName(route);
    if (routeName == null) {
      return;
    }
    if (_lastTrackedRouteName == routeName) {
      return;
    }
    _lastTrackedRouteName = routeName;
    unawaited(onScreenView(screenName: routeName, screenClass: route.runtimeType.toString()));
  }

  String? _resolveRouteName(Route<dynamic>? route) {
    if (route == null) {
      return null;
    }

    final String? settingsName = route.settings.name?.trim();
    if (settingsName != null && settingsName.isNotEmpty) {
      return settingsName;
    }

    final String fallback = route.runtimeType.toString().trim();
    if (fallback.isEmpty) {
      return null;
    }
    return fallback;
  }
}
