import 'package:Prism/core/analytics/analytics_route_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('emits screen transitions once per route change', (WidgetTester tester) async {
    final List<String> screens = <String>[];
    final AnalyticsRouteObserver observer = AnalyticsRouteObserver(
      onScreenView: ({required String screenName, String? screenClass, Map<String, Object?>? parameters}) async {
        screens.add(screenName);
      },
    );

    final MaterialPageRoute<void> homeRoute = MaterialPageRoute<void>(
      builder: (_) => const SizedBox(),
      settings: const RouteSettings(name: '/home'),
    );
    final MaterialPageRoute<void> detailsRoute = MaterialPageRoute<void>(
      builder: (_) => const SizedBox(),
      settings: const RouteSettings(name: '/details'),
    );

    observer.didPush(homeRoute, null);
    observer.didPush(detailsRoute, homeRoute);
    observer.didPop(detailsRoute, homeRoute);

    await tester.pump();

    expect(screens, <String>['/home', '/details', '/home']);
  });

  testWidgets('does not emit duplicate entries for same route name', (WidgetTester tester) async {
    final List<String> screens = <String>[];
    final AnalyticsRouteObserver observer = AnalyticsRouteObserver(
      onScreenView: ({required String screenName, String? screenClass, Map<String, Object?>? parameters}) async {
        screens.add(screenName);
      },
    );

    final MaterialPageRoute<void> firstHome = MaterialPageRoute<void>(
      builder: (_) => const SizedBox(),
      settings: const RouteSettings(name: '/home'),
    );
    final MaterialPageRoute<void> replacementHome = MaterialPageRoute<void>(
      builder: (_) => const SizedBox(),
      settings: const RouteSettings(name: '/home'),
    );

    observer.didPush(firstHome, null);
    observer.didReplace(newRoute: replacementHome, oldRoute: firstHome);

    await tester.pump();

    expect(screens, <String>['/home']);
  });

  testWidgets('falls back to route type when route name is missing', (WidgetTester tester) async {
    final List<String> screens = <String>[];
    final AnalyticsRouteObserver observer = AnalyticsRouteObserver(
      onScreenView: ({required String screenName, String? screenClass, Map<String, Object?>? parameters}) async {
        screens.add(screenName);
      },
    );

    final MaterialPageRoute<void> unnamedRoute = MaterialPageRoute<void>(builder: (_) => const SizedBox());

    observer.didPush(unnamedRoute, null);

    await tester.pump();

    expect(screens.single, contains('MaterialPageRoute'));
  });
}
