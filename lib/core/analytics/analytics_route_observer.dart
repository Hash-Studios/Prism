import 'dart:async';

import 'package:Prism/core/debug/performance_probe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef AnalyticsScreenViewCallback =
    Future<void> Function({required String screenName, String? screenClass, Map<String, Object?>? parameters});

class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver({required this.onScreenView});

  final AnalyticsScreenViewCallback onScreenView;

  Route<dynamic>? _lastTrackedRoute;

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
    if (identical(_lastTrackedRoute, route)) {
      return;
    }
    _lastTrackedRoute = route;
    if (!kReleaseMode) {
      final Stopwatch sw = Stopwatch()..start();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PerformanceProbe.emit(kind: 'route_first_frame', name: routeName, durationMs: sw.elapsedMilliseconds);
      });
    }
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
