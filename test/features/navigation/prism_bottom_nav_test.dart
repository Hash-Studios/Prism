import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/prism_theme_options.dart';
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
  StackRouter? stackRouterOfIndex(int index) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_FakeTabsRouter router, Widget child, {bool reduceMotion = false}) => MaterialApp(
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: app!,
  ),
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

  testWidgets('the tabs use the current app icons, the same glyph whether active or not', (tester) async {
    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, const Center(child: PrismBottomNav())));

    IconData iconOf(String label) =>
        tester.widget<Icon>(find.descendant(of: find.byTooltip(label), matching: find.byType(Icon))).icon!;

    expect(iconOf('Home'), JamIcons.home_f);
    expect(iconOf('Search'), JamIcons.search);
    expect(iconOf('Rewards'), JamIcons.gift_f);
    expect(iconOf('Collections'), JamIcons.grid_f);

    router.setActiveIndex(1);
    await tester.pumpAndSettle();

    expect(iconOf('Home'), JamIcons.home_f);
    expect(iconOf('Search'), JamIcons.search);
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

  testWidgets('the pill is 56 high and the tap targets are at least 48', (tester) async {
    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, const Center(child: PrismBottomNav())));

    expect(tester.getSize(find.byType(PrismBottomNav)).height, 56);
    expect(tester.getSize(find.byTooltip('Home')).shortestSide, greaterThanOrEqualTo(48));
  });

  testWidgets('a filled circle sits behind the active tab only and follows the selection', (tester) async {
    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, const Center(child: PrismBottomNav())));

    Color? circleBehind(IconData icon) {
      final container = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(AnimatedContainer)),
      );
      return (container.decoration! as BoxDecoration).color;
    }

    expect(circleBehind(JamIcons.home_f), isNot(Colors.transparent));
    expect(circleBehind(JamIcons.search), Colors.transparent);

    router.setActiveIndex(1);
    await tester.pumpAndSettle();

    expect(circleBehind(JamIcons.home_f), Colors.transparent);
    expect(circleBehind(JamIcons.search), isNot(Colors.transparent));
  });

  testWidgets('scrolling down hides the bar and shows a scroll to top button that scrolls up', (tester) async {
    final handle = tester.ensureSemantics();
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
        reduceMotion: true,
      ),
    );
    final Finder toTop = find.bySemanticsLabel('Scroll to top');
    expect(toTop, findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(toTop, findsOneWidget);

    await tester.tap(find.byIcon(JamIcons.arrow_up));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    handle.dispose();
  });

  testWidgets('tapping the active tab again pops that tab back to its root', (tester) async {
    final router = _TestRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    final tabs = router.innerRouterOf<TabsRouter>('Shell')!;
    final searchStack = tabs.stackRouterOfIndex(1)!;
    unawaited(searchStack.push(const UserSearchRoute()));
    await tester.pumpAndSettle();
    expect(find.text(UserSearchRoute.name), findsOneWidget);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(tabs.activeIndex, 1);
    expect(searchStack.stack.length, 1);
    expect(find.text(SearchRoute.name), findsOneWidget);
    expect(find.text(UserSearchRoute.name), findsNothing);
  });

  testWidgets('tapping another tab switches to it', (tester) async {
    final router = _TestRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collections'));
    await tester.pumpAndSettle();

    expect(router.innerRouterOf<TabsRouter>('Shell')!.activeIndex, 3);
  });

  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    testWidgets('${option.label}: active and inactive icons are readable with the real theme', (tester) async {
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);
      await tester.pumpWidget(MaterialApp.router(theme: theme, routerConfig: _TestRouter().config()));
      await tester.pumpAndSettle();

      final Color pill = theme.primaryColor;
      final Icon active = tester.widget<Icon>(find.descendant(of: find.byTooltip('Home'), matching: find.byType(Icon)));
      final Icon inactive = tester.widget<Icon>(
        find.descendant(of: find.byTooltip('Search'), matching: find.byType(Icon)),
      );

      expect(contrastRatio(active.color!, pill), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(Color.alphaBlend(inactive.color!, pill), pill), greaterThanOrEqualTo(2));
    });
  }
}
