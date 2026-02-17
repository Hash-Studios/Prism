import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/router/app_route_factory.dart' as app_route_factory;
import 'package:Prism/core/router/undefined_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppNavigatorHost extends StatefulWidget {
  const AppNavigatorHost({super.key, required this.initialRouteName});

  final String initialRouteName;

  @override
  State<AppNavigatorHost> createState() => _AppNavigatorHostState();
}

class _AppNavigatorHostState extends State<AppNavigatorHost> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final SentryNavigatorObserver _sentryNavigatorObserver = SentryNavigatorObserver(
    enableAutoTransactions: false,
    ignoreRoutes: <String>['/'],
  );

  void _handleNestedPop(Object? result) {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<NavigatorObserver> observers = <NavigatorObserver>[observer];
    if (MonitoringRuntime.reporter.isEnabled) {
      observers.add(_sentryNavigatorObserver);
    }

    return NavigatorPopHandler<Object?>(
      onPopWithResult: _handleNestedPop,
      child: Navigator(
        key: _navigatorKey,
        initialRoute: widget.initialRouteName,
        onGenerateRoute: app_route_factory.generateRoute,
        onUnknownRoute: (settings) => CupertinoPageRoute(
          builder: (context) => UndefinedScreen(name: settings.name),
        ),
        observers: observers,
      ),
    );
  }
}
