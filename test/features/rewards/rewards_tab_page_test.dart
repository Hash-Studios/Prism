import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TabsRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Shell',
        builder: (_) => const AutoTabsRouter(routes: <PageRouteInfo>[RewardsTabRoute(), HomeTabRoute()]),
      ),
      children: <AutoRoute>[
        AutoRoute(path: 'rewards', page: RewardsTabRoute.page),
        AutoRoute(
          path: 'home',
          page: PageInfo(HomeTabRoute.name, builder: (_) => const Text('Home tab')),
        ),
      ],
    ),
  ];
}

void main() {
  late _TabsRouter router;

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
    router = _TabsRouter();
  });

  tearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

  Future<void> pumpTabs(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> showTab(WidgetTester tester, int index) async {
    router.innerRouterOf<TabsRouter>('Shell')!.setActiveIndex(index);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the Rewards tab has no back button', (tester) async {
    await pumpTabs(tester);

    expect(find.byTooltip('Back'), findsNothing);
    expect(find.text('Rewards'), findsOneWidget);
  });

  testWidgets('the Rewards tab stops drawing frames while another tab shows, and resumes when it returns', (
    tester,
  ) async {
    await pumpTabs(tester);
    expect(tester.binding.hasScheduledFrame, isTrue);

    await showTab(tester, 1);
    expect(find.text('Home tab'), findsOneWidget);
    expect(find.byType(RewardsPage, skipOffstage: false), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await showTab(tester, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
