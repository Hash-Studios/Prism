import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/layout_prefs_scope.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

PageInfo _stub(String name) => PageInfo(name, builder: (_) => Text(name));

class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [HomeTabRoute(), SearchTabRoute(), RewardsTabRoute(), CollectionTabRoute()],
      builder: (context, child) => Column(
        children: [
          Expanded(child: child),
          const PrismBottomNav(),
        ],
      ),
    );
  }
}

class _TestRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo('Shell', builder: (_) => const _Shell()),
      children: [
        AutoRoute(path: 'home', page: _stub(HomeTabRoute.name)),
        AutoRoute(
          path: 'search',
          page: PageInfo(SearchTabRoute.name, builder: (_) => const AutoRouter()),
          children: [
            AutoRoute(path: '', page: _stub(SearchRoute.name)),
            AutoRoute(path: 'users', page: _stub(UserSearchRoute.name)),
          ],
        ),
        AutoRoute(path: 'rewards', page: _stub(RewardsTabRoute.name)),
        AutoRoute(path: 'collection', page: _stub(CollectionTabRoute.name)),
      ],
    ),
  ];
}

Future<_TestRouter> _pumpBar(WidgetTester tester, ValueNotifier<LayoutPrefs> prefs) async {
  final router = _TestRouter();
  await tester.pumpWidget(
    LayoutPrefsScope(
      prefs: prefs,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

  testWidgets('the bar draws the visible tabs in the user order, left to right', (tester) async {
    final prefs = ValueNotifier<LayoutPrefs>(
      const LayoutPrefs(tabOrder: [NavTab.collection, NavTab.home, NavTab.search, NavTab.rewards]),
    );
    addTearDown(prefs.dispose);
    await _pumpBar(tester, prefs);

    double centerOf(String label) => tester.getCenter(find.byTooltip(label)).dx;
    final List<String> leftToRight = ['Home', 'Search', 'Rewards', 'Collections']
      ..sort((a, b) => centerOf(a).compareTo(centerOf(b)));

    expect(leftToRight, ['Collections', 'Home', 'Search', 'Rewards']);
  });

  testWidgets('a hidden tab leaves the bar and the More button appears', (tester) async {
    final prefs = ValueNotifier<LayoutPrefs>(const LayoutPrefs(hiddenTabs: {NavTab.rewards}));
    addTearDown(prefs.dispose);
    await _pumpBar(tester, prefs);

    expect(find.byTooltip('Rewards'), findsNothing);
    for (final label in ['Home', 'Search', 'Collections', 'More']) {
      expect(find.byTooltip(label), findsOneWidget);
    }
  });

  testWidgets('with nothing hidden there is no More button', (tester) async {
    final prefs = ValueNotifier<LayoutPrefs>(const LayoutPrefs());
    addTearDown(prefs.dispose);
    await _pumpBar(tester, prefs);

    expect(find.byTooltip('More'), findsNothing);
  });

  testWidgets('More lists the hidden tabs and Edit tabs, and picking a hidden tab switches to it', (tester) async {
    final prefs = ValueNotifier<LayoutPrefs>(const LayoutPrefs(hiddenTabs: {NavTab.rewards}));
    addTearDown(prefs.dispose);
    final router = await _pumpBar(tester, prefs);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Edit tabs'), findsOneWidget);

    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();

    expect(router.innerRouterOf<TabsRouter>('Shell')!.activeIndex, NavTab.rewards.index);
  });

  testWidgets('a deep link to a hidden tab shows its page and selects More', (tester) async {
    final handle = tester.ensureSemantics();
    final prefs = ValueNotifier<LayoutPrefs>(const LayoutPrefs(hiddenTabs: {NavTab.rewards}));
    addTearDown(prefs.dispose);
    final router = await _pumpBar(tester, prefs);

    router.innerRouterOf<TabsRouter>('Shell')!.setActiveIndex(NavTab.rewards.index);
    await tester.pumpAndSettle();

    expect(find.text(RewardsTabRoute.name), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('More')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Home')), isSemantics(isSelected: false, isButton: true));
    handle.dispose();
  });

  testWidgets('changing the prefs notifier rebuilds the bar without a new router', (tester) async {
    final prefs = ValueNotifier<LayoutPrefs>(const LayoutPrefs(hiddenTabs: {NavTab.rewards}));
    addTearDown(prefs.dispose);
    final router = await _pumpBar(tester, prefs);
    final TabsRouter tabs = router.innerRouterOf<TabsRouter>('Shell')!;

    expect(find.byTooltip('Rewards'), findsNothing);
    expect(find.byTooltip('More'), findsOneWidget);

    prefs.value = const LayoutPrefs();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Rewards'), findsOneWidget);
    expect(find.byTooltip('More'), findsNothing);
    expect(router.innerRouterOf<TabsRouter>('Shell'), same(tabs));
  });
}
