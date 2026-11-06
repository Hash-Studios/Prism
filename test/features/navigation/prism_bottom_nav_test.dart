import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/side_safe_column.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

/// True while the docked band is on screen and takes taps.
bool _bandShown(WidgetTester tester) => find.byType(PrismBottomNav).hitTestable().evaluate().isNotEmpty;

/// Moves the list without leaving a fling, so a later pump does not scroll it back.
Future<void> _dragList(WidgetTester tester, Offset offset) async {
  final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
  await gesture.moveBy(offset);
  await tester.pump(const Duration(milliseconds: 400));
  await gesture.up();
  await tester.pumpAndSettle();
}

PageInfo _stub(String name) => PageInfo(name, builder: (_) => Text(name));

class _Shell extends StatelessWidget {
  const _Shell({this.axis = Axis.horizontal});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [HomeTabRoute(), SearchTabRoute(), RewardsTabRoute(), CollectionTabRoute()],
      builder: (context, child) => Column(
        children: [
          Expanded(child: child),
          PrismBottomNav(axis: axis),
        ],
      ),
    );
  }
}

class _TestRouter extends RootStackRouter {
  _TestRouter({this.axis = Axis.horizontal});

  final Axis axis;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo('Shell', builder: (_) => _Shell(axis: axis)),
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

class _SideWidthsProbe extends StatelessWidget {
  const _SideWidthsProbe();

  @override
  Widget build(BuildContext context) => Text('${screenSideSafeColumnWidth(context)}:${sideSafeColumnWidth(context)}');
}

Widget _host(_FakeTabsRouter router, Widget child, {bool reduceMotion = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

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

    expect(iconOf('Home'), Icons.home_rounded);
    expect(iconOf('Search'), Icons.search_rounded);
    expect(iconOf('Rewards'), Icons.card_giftcard_rounded);
    expect(iconOf('Collections'), Icons.grid_view_rounded);

    router.setActiveIndex(1);
    await tester.pumpAndSettle();

    expect(iconOf('Home'), Icons.home_rounded);
    expect(iconOf('Search'), Icons.search_rounded);
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

  testWidgets('the vertical rail keeps named selected semantics and semantic tab switching', (tester) async {
    final handle = tester.ensureSemantics();
    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, const Center(child: PrismBottomNav(axis: Axis.vertical))));

    for (final label in ['Home', 'Search', 'Rewards', 'Collections']) {
      expect(find.byTooltip(label), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel(label)), isSemantics(isButton: true));
    }
    expect(tester.getSemantics(find.bySemanticsLabel('Home')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Search')), isSemantics(isSelected: false, isButton: true));

    final int rewardsNodeId = tester.getSemantics(find.bySemanticsLabel('Rewards')).id;
    tester.platformDispatcher.onSemanticsActionEvent!(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: rewardsNodeId),
    );
    await tester.pumpAndSettle();
    expect(router.activeIndex, 2);
    expect(tester.getSemantics(find.bySemanticsLabel('Rewards')), isSemantics(isSelected: true, isButton: true));
    final NavTabSelectedEvent event = analytics.events.whereType<NavTabSelectedEvent>().single;
    expect(event.fromTab, NavTabValue.home);
    expect(event.toTab, NavTabValue.streak);

    handle.dispose();
  });

  testWidgets('the pill is 56 high and the tap targets are at least 48', (tester) async {
    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, const Center(child: PrismBottomNav())));

    expect(tester.getSize(find.byType(PrismBottomNav)).height, 56);
    expect(tester.getSize(find.byTooltip('Home')).shortestSide, greaterThanOrEqualTo(48));
  });

  testWidgets('the row shows a label under each icon on a pill, the rail and a narrow row show icons only', (
    tester,
  ) async {
    final router = _FakeTabsRouter();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3)),
        child: _host(router, const Center(child: PrismBottomNav())),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PrismBottomNav)), Size(PrismBottomNav.maxLength(labels: true), 56));
    expect(tester.getSize(find.byTooltip('Home')), const Size(68, 48));
    final Text home = tester.widget<Text>(find.text('Home'));
    expect(home.style!.fontSize, 12);
    expect(home.maxLines, 1);
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('Home'))).scale(10),
      12,
      reason: 'text scale capped at 1.2',
    );
    expect(
      tester.getTopLeft(find.text('Home')).dy,
      greaterThan(tester.getBottomLeft(find.byIcon(Icons.home_rounded)).dy),
    );
    final BoxDecoration active =
        tester
                .widget<AnimatedContainer>(
                  find.ancestor(of: find.text('Home'), matching: find.byType(AnimatedContainer)),
                )
                .decoration!
            as BoxDecoration;
    expect(active.shape, BoxShape.rectangle);
    expect(active.borderRadius, BorderRadius.circular(PrismRadius.pill));

    for (final Widget nav in const <Widget>[PrismBottomNav(axis: Axis.vertical), PrismBottomNav(labels: false)]) {
      await tester.pumpWidget(_host(router, Center(child: nav)));
      expect(find.text('Home'), findsNothing);
      expect(tester.getSize(find.byTooltip('Home')), const Size(48, 48));
    }
  });

  testWidgets('a filled shape sits behind the active tab only and follows the selection', (tester) async {
    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, const Center(child: PrismBottomNav())));

    Color? circleBehind(IconData icon) {
      final container = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(AnimatedContainer)),
      );
      return (container.decoration! as BoxDecoration).color;
    }

    expect(circleBehind(Icons.home_rounded), isNot(Colors.transparent));
    expect(circleBehind(Icons.search_rounded), Colors.transparent);

    router.setActiveIndex(1);
    await tester.pumpAndSettle();

    expect(circleBehind(Icons.home_rounded), Colors.transparent);
    expect(circleBehind(Icons.search_rounded), isNot(Colors.transparent));
  });

  Widget list(ScrollController controller) => ListView.builder(
    controller: controller,
    itemCount: 100,
    itemBuilder: (_, int i) => SizedBox(height: 80, child: Text('row $i')),
  );

  testWidgets('scrolling down slides the whole band away and offers no floating scroll-to-top button', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_FakeTabsRouter(), BottomBar(child: list(controller)), reduceMotion: true));
    expect(_bandShown(tester), isTrue);

    await _dragList(tester, const Offset(0, -1600));
    expect(controller.offset, greaterThan(1200));
    expect(_bandShown(tester), isFalse);
    expect(find.bySemanticsLabel(AppLocalizationsEn().navigationScrollToTop), findsNothing);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    handle.dispose();
  });

  testWidgets('scrolling back up brings the band back', (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_FakeTabsRouter(), BottomBar(child: list(controller)), reduceMotion: true));

    await _dragList(tester, const Offset(0, -1500));
    expect(controller.offset, greaterThan(0));
    // Issue #543: hiding on the way down must not stick after the user scrolls back.
    expect(_bandShown(tester), isFalse);

    await _dragList(tester, const Offset(0, 300));
    expect(controller.offset, greaterThan(0));
    expect(_bandShown(tester), isTrue);
  });

  testWidgets('tapping the active tab again scrolls its list to the top and says so to screen readers', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_FakeTabsRouter(), BottomBar(child: list(controller)), reduceMotion: true));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Home')),
      isSemantics(isSelected: true, isButton: true, hint: AppLocalizationsEn().navigationScrollToTop),
    );
    expect(tester.getSemantics(find.bySemanticsLabel('Search')).hint, isEmpty);

    await _dragList(tester, const Offset(0, -1500));
    await _dragList(tester, const Offset(0, 300));
    expect(controller.offset, greaterThan(900));

    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(analytics.events.whereType<NavTabSelectedEvent>(), isEmpty);
    handle.dispose();
  });

  // A route pop notifies MediaQuery, and Scrollable replaces its position.
  // The tap must drive that new position, not the disposed one. See GitHub issue #543.
  testWidgets('scroll to top after the scroll position is replaced does not use the disposed position', (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    Future<void> pumpAt(double devicePixelRatio) {
      return tester.pumpWidget(
        _host(
          _FakeTabsRouter(),
          Builder(
            builder: (BuildContext context) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(devicePixelRatio: devicePixelRatio),
                child: BottomBar(child: list(controller)),
              );
            },
          ),
          reduceMotion: true,
        ),
      );
    }

    await pumpAt(1);
    await _dragList(tester, const Offset(0, -1500));
    await _dragList(tester, const Offset(0, 300));
    expect(controller.offset, greaterThan(0));

    await pumpAt(3);
    await tester.pump();
    await tester.tap(find.byTooltip('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    expect(controller.offset, 0);
  });

  testWidgets('navigating away during scroll to top does not use a disposed position', (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    Future<void> pumpBody({required bool showList}) {
      return tester.pumpWidget(
        _host(
          _FakeTabsRouter(),
          BottomBar(child: showList ? list(controller) : const SizedBox.expand(key: Key('left-the-list'))),
        ),
      );
    }

    await pumpBody(showList: true);
    await _dragList(tester, const Offset(0, -1500));
    await _dragList(tester, const Offset(0, 300));
    expect(_bandShown(tester), isTrue);

    await tester.tap(find.byTooltip('Home'));
    await tester.pump();
    await pumpBody(showList: false);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    expect(_bandShown(tester), isTrue);
  });

  group('iOS right safe column (iPhone Duo outer screen)', () {
    double bodySafeColumnWidth = -1;

    Future<void> pumpDuo(WidgetTester tester, {Widget? child}) async {
      final display = tester.platformDispatcher.displays.first;
      display
        ..devicePixelRatio = 3
        ..size = const Size(466 * 3, 678 * 3);
      addTearDown(display.reset);
      tester.view
        ..devicePixelRatio = 3
        ..physicalSize = const Size(466 * 3, 678 * 3)
        ..viewPadding = const FakeViewPadding(right: 84 * 3, bottom: 34 * 3)
        ..padding = const FakeViewPadding(right: 84 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          _FakeTabsRouter(),
          BottomBar(
            child:
                child ??
                Builder(
                  builder: (context) {
                    bodySafeColumnWidth = sideSafeColumnWidth(context);
                    return const SizedBox.expand(key: Key('body'));
                  },
                ),
          ),
        ),
      );
    }

    testWidgets('puts the tabs in a vertical rail in the column, beside the content', (tester) async {
      await pumpDuo(tester);

      expect(tester.widget<PrismBottomNav>(find.byType(PrismBottomNav)).axis, Axis.vertical);
      expect(tester.getRect(find.byType(PrismBottomNav)).left, greaterThanOrEqualTo(466 - 84));
      expect(tester.getSize(find.byKey(const Key('body'))).width, 466 - 84);
      expect(bodySafeColumnWidth, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('keeps the floating bar on other platforms', (tester) async {
      await pumpDuo(tester);

      expect(tester.widget<PrismBottomNav>(find.byType(PrismBottomNav)).axis, Axis.horizontal);
      expect(tester.getSize(find.byKey(const Key('body'))).width, 466);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('updates a const whole-screen probe after a same-size native inset change', (tester) async {
      await pumpDuo(tester, child: const _SideWidthsProbe());

      expect(find.text('84.0:0.0'), findsOneWidget);

      tester.view
        ..viewPadding = const FakeViewPadding(right: 100 * 3, bottom: 34 * 3)
        ..padding = const FakeViewPadding(right: 100 * 3, bottom: 34 * 3);
      await tester.pump();

      expect(find.text('100.0:0.0'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('tapping the active tab again pops that tab back to its root', (tester) async {
    final router = _TestRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
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

  testWidgets('tapping the active vertical-rail tab again pops that tab back to its root', (tester) async {
    final router = _TestRouter(axis: Axis.vertical);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
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
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collections'));
    await tester.pumpAndSettle();

    expect(router.innerRouterOf<TabsRouter>('Shell')!.activeIndex, 3);
  });

  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    testWidgets(
      '${prismThemeDisplayName(option, AppLocalizationsEn())}: active and inactive tabs are readable with the real theme',
      (tester) async {
        final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);
        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            routerConfig: _TestRouter().config(),
          ),
        );
        await tester.pumpAndSettle();

        final Color pill = theme.primaryColor;
        final Icon active = tester.widget<Icon>(
          find.descendant(of: find.byTooltip('Home'), matching: find.byType(Icon)),
        );
        final Icon inactive = tester.widget<Icon>(
          find.descendant(of: find.byTooltip('Search'), matching: find.byType(Icon)),
        );

        expect(contrastRatio(active.color!, pill), greaterThanOrEqualTo(4.5));
        // The inactive icon and label share one colour, so it must read as text.
        expect(contrastRatio(Color.alphaBlend(inactive.color!, pill), pill), greaterThanOrEqualTo(4.5));
      },
    );
  }
}
