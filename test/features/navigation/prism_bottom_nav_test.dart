import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _FakeTabsRouter extends ChangeNotifier implements TabsRouter {
  int _active = 0;

  @override
  int get activeIndex => _active;

  @override
  void setActiveIndex(int index, {bool notify = true}) {
    _active = index;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_FakeTabsRouter router, Widget child) => MaterialApp(
  home: TabsRouterScope(
    controller: router,
    stateHash: 0,
    child: Scaffold(body: child),
  ),
);

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

  testWidgets('the four destinations are named buttons and only the active one is selected', (tester) async {
    final handle = tester.ensureSemantics();
    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, const Center(child: PrismBottomNav())));

    for (final label in ['Home', 'Search', 'Rewards', 'Collections']) {
      expect(find.byTooltip(label), findsOneWidget);
    }
    expect(tester.getSemantics(find.bySemanticsLabel('Home')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Search')), isSemantics(isSelected: false, isButton: true));
    handle.dispose();
  });

  testWidgets('tapping a tab switches to it and tapping the active tab does nothing', (tester) async {
    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, const Center(child: PrismBottomNav())));

    await tester.tap(find.byTooltip('Rewards'));
    await tester.pumpAndSettle();
    expect(router.activeIndex, 2);
    expect(analytics.events.where((e) => e.eventName == 'nav_tab_selected'), hasLength(1));

    await tester.tap(find.byTooltip('Rewards'));
    await tester.pumpAndSettle();
    expect(router.activeIndex, 2);
    expect(analytics.events.where((e) => e.eventName == 'nav_tab_selected'), hasLength(1));
  });

  testWidgets('the pill is 60 high and the tap targets are at least 48', (tester) async {
    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, const Center(child: PrismBottomNav())));

    expect(tester.getSize(find.byType(PrismBottomNav)).height, 60);
    expect(tester.getSize(find.byTooltip('Home')).shortestSide, greaterThanOrEqualTo(48));
  });

  testWidgets('scrolling down hides the bar and shows a back to top button that scrolls up', (tester) async {
    final router = _FakeTabsRouter();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        router,
        BottomBar(
          child: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemBuilder: (_, i) => SizedBox(height: 80, child: Text('row $i')),
          ),
        ),
      ),
    );
    final Finder toTop = find.byTooltip('Back to top');
    expect(
      tester.widget<IgnorePointer>(find.ancestor(of: toTop, matching: find.byType(IgnorePointer)).first).ignoring,
      isTrue,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(
      tester.widget<IgnorePointer>(find.ancestor(of: toTop, matching: find.byType(IgnorePointer)).first).ignoring,
      isFalse,
    );

    await tester.tap(toTop);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });
}
