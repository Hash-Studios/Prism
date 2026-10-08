import 'dart:async';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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

  testWidgets('the active tab circle uses the theme primary and onPrimary', (tester) async {
    final router = _TestRouter();
    const scheme = ColorScheme.light(primary: Color(0xFF123456), onPrimary: Color(0xFFABCDEF));
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(colorScheme: scheme),
        routerConfig: router.config(),
      ),
    );
    await tester.pumpAndSettle();

    final circle = tester.widget<Container>(
      find.ancestor(of: find.byTooltip('Home'), matching: find.byType(Container)).first,
    );
    expect((circle.decoration! as BoxDecoration).color, scheme.primary);
    final icon = tester.widget<Icon>(find.descendant(of: find.byTooltip('Home'), matching: find.byType(Icon)));
    expect(icon.color, scheme.onPrimary);
  });

  testWidgets('the selected tab is exposed as selected to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    final router = _TestRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(find.byTooltip('Home')), isSemantics(isSelected: true));
    expect(tester.getSemantics(find.byTooltip('Search')), isSemantics(isSelected: false));

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(find.byTooltip('Home')), isSemantics(isSelected: false));
    expect(tester.getSemantics(find.byTooltip('Search')), isSemantics(isSelected: true));
    handle.dispose();
  });

  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    testWidgets('${option.label}: active and inactive icons are readable with the real theme', (tester) async {
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);
      await tester.pumpWidget(MaterialApp.router(theme: theme, routerConfig: _TestRouter().config()));
      await tester.pumpAndSettle();

      final Icon active = tester.widget<Icon>(find.descendant(of: find.byTooltip('Home'), matching: find.byType(Icon)));
      final Icon inactive = tester.widget<Icon>(
        find.descendant(of: find.byTooltip('Search'), matching: find.byType(Icon)),
      );

      expect(contrastRatio(active.color!, theme.colorScheme.primary), greaterThanOrEqualTo(4.5));
      expect(
        contrastRatio(Color.alphaBlend(inactive.color!, theme.primaryColor), theme.primaryColor),
        greaterThanOrEqualTo(3),
      );
    });
  }
}
