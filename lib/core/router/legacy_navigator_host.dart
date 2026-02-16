import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/routes/router.dart' as legacy_router;
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:flutter/cupertino.dart';

class LegacyNavigatorHost extends StatefulWidget {
  const LegacyNavigatorHost({super.key, required this.initialRouteName});

  final String initialRouteName;

  @override
  State<LegacyNavigatorHost> createState() => _LegacyNavigatorHostState();
}

class _LegacyNavigatorHostState extends State<LegacyNavigatorHost> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  Future<bool> _onWillPop() async {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Navigator(
        key: _navigatorKey,
        initialRoute: widget.initialRouteName,
        onGenerateRoute: legacy_router.generateRoute,
        onUnknownRoute: (settings) => CupertinoPageRoute(
          builder: (context) => UndefinedScreen(name: settings.name),
        ),
        observers: <NavigatorObserver>[observer],
      ),
    );
  }
}
