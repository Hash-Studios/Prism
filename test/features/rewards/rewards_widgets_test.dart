import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/features/ads/views/widgets/experimental_inline_ad.dart';
import 'package:Prism/features/badges/biz/bloc/badges_bloc.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/drops/drops.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/features/rewards/views/widgets/balance_card.dart';
import 'package:Prism/features/rewards/views/widgets/creator_progress_card.dart';
import 'package:Prism/features/rewards/views/widgets/freeze_card.dart';
import 'package:Prism/features/rewards/views/widgets/rank_progress_card.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_hero.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/favourite_test_scope.dart';
import '../quests/fake_quests_repository.dart';

class _MockBadgesBloc extends MockBloc<BadgesEvent, BadgesState> implements BadgesBloc {}

class _MockDropsBloc extends MockBloc<DropsEvent, DropsState> implements DropsBloc {}

class _RefreshTabsRouter extends RootStackRouter {
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

Map<String, dynamic> _creatorEconomy(int approved) => <String, dynamic>{
  'rev': approved,
  'creator': <String, dynamic>{
    'version': 1,
    'trackedSinceMs': DateTime.utc(2026, 10, 2).millisecondsSinceEpoch,
    'approvedWalls': approved,
    'uniqueMembers': 7,
    'awardedIds': <String>[],
    'milestones': <Object?>[
      <String, Object?>{'id': 'approved_5', 'metric': 'approvedWalls', 'target': 5, 'xp': 100},
      <String, Object?>{'id': 'members_10', 'metric': 'uniqueMembers', 'target': 10, 'xp': 50},
    ],
    'weeks': <Object?>[],
  },
};

/// The Rewards page builds the Today card and the Drop card, which each read a bloc from [getIt].
void _registerEconomyBlocs() {
  getIt.registerFactory<QuestsBloc>(() => QuestsBloc(FakeQuestsRepository()));
  getIt.registerFactory<DropsBloc>(() {
    final _MockDropsBloc drops = _MockDropsBloc();
    whenListen(drops, const Stream<DropsState>.empty(), initialState: DropsState.initial());
    return drops;
  });
}

class _MockShopBloc extends MockBloc<StreakShopEvent, StreakShopState> implements StreakShopBloc {}

PrismWallpaper _shopWallpaper() => const PrismWallpaper(
  core: WallpaperCore(id: 'shop-wall', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  requiredStreakDays: 7,
  streakShopCoinCost: 500,
);

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  await tester.pumpWidget(_app(theme, child));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpFavouriteCounts();
  final CoinsService svc = CoinsService.instance;
  final int balance = svc.balanceNotifier.value;

  setUpAll(() async {
    await (FontLoader('Proxima Nova')
          ..addFont(rootBundle.load('assets/fonts/ProximaNova-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/Proxima Nova Bold.otf'))
          ..addFont(rootBundle.load('assets/fonts/Proxima Nova Extrabold.otf')))
        .load();
    await (FontLoader('Fraunces')..addFont(rootBundle.load('assets/fonts/Fraunces-Variable.ttf'))).load();
  });

  setUp(() => DailyMomentConfig.enabledOverride = false);

  tearDown(() async {
    DailyMomentConfig.enabledOverride = null;
    app_state.prismUser = app_constants.createGuestPrismUser();
    svc.streakNotifier.value = StreakStatus.empty;
    svc.xpNotifier.value = XpStatus.empty();
    svc.balanceNotifier.value = balance;
    await getIt.reset();
  });

  testWidgets('standalone guest rewards can navigate back', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RewardsPage())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sign in to use Rewards'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('signed-in rewards page shows the header pill and every section', (tester) async {
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'rewards-page-user'
      ..loggedIn = true;
    svc.balanceNotifier.value = 240;
    getIt.registerFactory<StreakShopBloc>(() {
      final _MockShopBloc shop = _MockShopBloc();
      whenListen(
        shop,
        const Stream<StreakShopState>.empty(),
        initialState: const StreakShopState(status: StreakShopStatus.success),
      );
      return shop;
    });
    final _MockBadgesBloc badges = _MockBadgesBloc();
    whenListen(badges, const Stream<BadgesState>.empty(), initialState: const BadgesState());
    getIt.registerFactory<BadgesBloc>(() => badges);
    _registerEconomyBlocs();
    getIt.registerSingleton<FirestoreClient>(CoinsTestFirestore());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kDarkTheme,
        builder: favouriteTestBuilder,
        home: const RewardsPage(showBack: false),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('240 Prism coins'), findsWidgets);
    expect(find.byType(CoinBalancePill), findsOneWidget);
    expect(find.text('Use your coins'), findsOneWidget);
    expect(find.text('Earn coins'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Activity'), 400, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('No coin activity yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpRewardsPage(WidgetTester tester, {required bool scrollToEarn}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'rewards-earn-scroll-$scrollToEarn'
      ..loggedIn = true;
    final _MockShopBloc shop = _MockShopBloc();
    whenListen(shop, const Stream<StreakShopState>.empty(), initialState: const StreakShopState());
    getIt.registerFactory<StreakShopBloc>(() => shop);
    final _MockBadgesBloc badges = _MockBadgesBloc();
    whenListen(badges, const Stream<BadgesState>.empty(), initialState: const BadgesState());
    getIt.registerFactory<BadgesBloc>(() => badges);
    _registerEconomyBlocs();
    getIt.registerSingleton<FirestoreClient>(CoinsTestFirestore());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        theme: kLightTheme,
        builder: favouriteTestBuilder,
        home: RewardsPage(showBack: false, scrollToEarn: scrollToEarn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<CoinsTestFirestore> prepareCreatorRefresh(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final CoinsTestBackend backend = CoinsTestBackend();
    await backend.install();
    getIt.registerFactory<StreakShopBloc>(() {
      final _MockShopBloc shop = _MockShopBloc();
      whenListen(shop, const Stream<StreakShopState>.empty(), initialState: const StreakShopState());
      return shop;
    });
    getIt.registerFactory<BadgesBloc>(() {
      final _MockBadgesBloc badges = _MockBadgesBloc();
      whenListen(badges, const Stream<BadgesState>.empty(), initialState: const BadgesState());
      return badges;
    });
    _registerEconomyBlocs();
    final CoinsTestFirestore firestore = CoinsTestFirestore()
      ..userData = <String, dynamic>{'coins': 100}
      ..docs['usersv2/${backend.userId}/private/economy'] = _creatorEconomy(2);
    getIt.registerSingleton<FirestoreClient>(firestore);
    return firestore;
  }

  testWidgets('opening standalone Rewards refreshes both mounted pages and keeps the tab usable', (tester) async {
    final CoinsTestFirestore firestore = await prepareCreatorRefresh(tester);
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        builder: favouriteTestBuilder,
        home: const RewardsPage(showBack: false),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Approved wallpapers: 2 / 5'), findsOneWidget);

    final Completer<Map<String, dynamic>?> response = Completer<Map<String, dynamic>?>();
    firestore.privateEconomyResponse = response.future;
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const RewardsPage())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RewardsPage, skipOffstage: false), findsNWidgets(2));
    expect(find.text('Approved wallpapers: 2 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);

    response.complete(_creatorEconomy(3));
    await tester.pump();
    await tester.pump();
    expect(find.text('Approved wallpapers: 3 / 5'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RewardsPage), findsOneWidget);
    expect(find.text('Approved wallpapers: 3 / 5'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to the Rewards tab refreshes progress with another mounted consumer', (tester) async {
    final CoinsTestFirestore firestore = await prepareCreatorRefresh(tester);
    final _RefreshTabsRouter router = _RefreshTabsRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        routerConfig: router.config(),
        builder: (context, child) => favouriteTestBuilder(
          context,
          Column(
            children: <Widget>[
              const CreatorProgressCard(),
              Expanded(child: child!),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Approved wallpapers: 2 / 5'), findsNWidgets(2));

    final TabsRouter tabs = router.innerRouterOf<TabsRouter>('Shell')!;
    tabs.setActiveIndex(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Home tab'), findsOneWidget);
    final Completer<Map<String, dynamic>?> response = Completer<Map<String, dynamic>?>();
    firestore.privateEconomyResponse = response.future;
    tabs.setActiveIndex(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Approved wallpapers: 2 / 5'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    response.complete(_creatorEconomy(3));
    await tester.pump();
    await tester.pump();
    expect(find.text('Approved wallpapers: 3 / 5'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrollToEarn brings the Earn coins section into view', (tester) async {
    await pumpRewardsPage(tester, scrollToEarn: true);
    final Finder earn = find.text('Earn coins');
    expect(earn, findsOneWidget);
    expect(tester.getTopLeft(earn).dy, lessThan(400));
  });

  testWidgets('without scrollToEarn the page starts at the top', (tester) async {
    await pumpRewardsPage(tester, scrollToEarn: false);
    expect(find.text('Earn coins'), findsNothing);
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('populated rewards cards fit at 320px and text scale 1.3 (${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      svc.streakNotifier.value = StreakStatus.empty.copyWith(
        count: 365,
        best: 500,
        streakDay: 7,
        active: true,
        claimedToday: true,
      );
      svc.balanceNotifier.value = 10000;

      for (final (String name, Widget child) in <(String, Widget)>[
        ('hero', const RewardsHero()),
        ('freeze card', FreezeCard(onEarnCoins: () {})),
        ('balance card', BalanceCard(onSeeUses: () {})),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,

            theme: brightness == Brightness.light ? kLightTheme : kDarkTheme,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(1.3)),
                child: SingleChildScrollView(child: SizedBox(width: 280, child: child)),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull, reason: name);
      }
    });

    testWidgets('rewards page fits 320px at text scale 1.3 (${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'rewards-layout-${brightness.name}'
        ..loggedIn = true;
      svc.streakNotifier.value = StreakStatus.empty.copyWith(
        count: 365,
        best: 500,
        streakDay: 7,
        active: true,
        claimedToday: true,
      );
      svc.balanceNotifier.value = 10000;
      final _MockShopBloc shop = _MockShopBloc();
      whenListen(
        shop,
        const Stream<StreakShopState>.empty(),
        initialState: StreakShopState(status: StreakShopStatus.success, items: <PrismWallpaper>[_shopWallpaper()]),
      );
      getIt.registerFactory<StreakShopBloc>(() => shop);
      final _MockBadgesBloc badges = _MockBadgesBloc();
      whenListen(badges, const Stream<BadgesState>.empty(), initialState: const BadgesState());
      getIt.registerFactory<BadgesBloc>(() => badges);
      _registerEconomyBlocs();
      final CoinsTestFirestore firestore = CoinsTestFirestore()
        ..transactions = <Map<String, dynamic>>[
          for (int i = 0; i < 9; i++)
            <String, dynamic>{
              'id': 'tx-$i',
              'userId': 'rewards-layout-${brightness.name}',
              'action': 'streakFreeze',
              'delta': i.isEven ? 50 : -50,
              'createdAt': DateTime.now(),
            },
        ];
      getIt.registerSingleton<FirestoreClient>(firestore);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: brightness == Brightness.light ? kLightTheme : kDarkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: favouriteTestBuilder(context, child),
          ),
          home: const RewardsPage(showBack: false),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      final Finder usesLink = find.text('What you can do with them');
      await tester.scrollUntilVisible(usesLink, 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(tester.getRect(usesLink).width, greaterThan(0));
      await tester.tap(usesLink);
      await tester.pumpAndSettle();
      expect(find.text('Use your coins'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Earn coins sits above Use your coins, which the link just scrolled to.
      await tester.scrollUntilVisible(find.text('Earn coins'), -200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(find.text('Ad'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1024, 1366);
      await tester.pump();
      final banner = tester.widget<ExperimentalInlineAd>(find.byType(ExperimentalInlineAd));
      expect(banner.availableWidth, lessThanOrEqualTo(640));
      expect(banner.availableWidth, greaterThan(0));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text(AppLocalizationsEn().economyCollectionUnlockedAtDays(7)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text(AppLocalizationsEn().economyCollectionUnlockedAtDays(7)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Show more'), 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(find.text('Show more'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('freeze sheet tracks balance changes while open', (tester) async {
    svc.balanceNotifier.value = 20;
    await _pump(tester, ThemeData.light(), FreezeCard(onEarnCoins: () {}));
    await tester.tap(find.textContaining('Get one'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('You need 50 coins.'), findsOneWidget);
    svc.balanceNotifier.value = 100;
    await tester.pump();
    expect(find.text('Balance after: 50'), findsOneWidget);
    expect(find.text('Buy'), findsOneWidget);
  });

  testWidgets('hero cycle settles when reduce motion is enabled while running', (tester) async {
    svc.streakNotifier.value = StreakStatus.empty.copyWith(count: 3, streakDay: 3, active: true);
    final reduce = ValueNotifier<bool>(false);
    addTearDown(reduce.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: ValueListenableBuilder<bool>(
          valueListenable: reduce,
          builder: (context, reduced, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: const Scaffold(body: RewardsHero()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    reduce.value = true;
    await tester.pump();
    final opacities = find.ancestor(of: find.byIcon(Icons.check_rounded), matching: find.byType(Opacity));
    expect(opacities, findsNWidgets(3));
    for (final opacity in tester.widgetList<Opacity>(opacities)) {
      expect(opacity.opacity, 1);
    }
  });

  for (final ThemeData theme in <ThemeData>[ThemeData.light(), ThemeData.dark()]) {
    final String mode = theme.brightness.name;

    testWidgets('hero: no streak ($mode)', (tester) async {
      await _pump(tester, theme, const RewardsHero());
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Open Prism every day to build a streak.'), findsOneWidget);
      expect(
        find.text('Finish day 7 for a chest of +${CoinPolicy.streakChestMin} to +${CoinPolicy.streakChestMax}'),
        findsOneWidget,
      );
      expect(find.text('Day 7'), findsOneWidget);
      expect(find.textContaining('Best'), findsNothing);
    });

    testWidgets('hero: claimed streak ($mode)', (tester) async {
      svc.streakNotifier.value = StreakStatus.empty.copyWith(
        count: 12,
        best: 21,
        streakDay: 5,
        active: true,
        claimedToday: true,
      );
      await _pump(tester, theme, const RewardsHero());
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Best 21 days'), findsOneWidget);
      expect(find.textContaining('Today is done. Come back tomorrow for +'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(5));
    });

    testWidgets('XP card: current rank and progress ($mode)', (tester) async {
      svc.xpNotifier.value = XpStatus(xp: 1240, weekXp: 40, rank: EconomyConfig.current.rankFor(1240));
      await _pump(tester, theme, const RankProgressCard());
      expect(find.text('Silver'), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().economyLifetimeXp(formatLocalizedNumber(1240, AppLocalizationsEn()))),
        findsOneWidget,
      );
      expect(find.text('760 XP to Gold'), findsOneWidget);
      final LinearProgressIndicator bar = tester.widget(find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo((1240 - 500) / (2000 - 500), 0.001));
      expect(find.bySemanticsLabel('Silver rank progress'), findsOneWidget);
    });

    testWidgets('XP card: the top rank has no next step ($mode)', (tester) async {
      svc.xpNotifier.value = XpStatus(xp: 9000, weekXp: 0, rank: EconomyConfig.current.rankFor(9000));
      await _pump(tester, theme, const RankProgressCard());
      expect(find.text('Prism'), findsOneWidget);
      expect(find.text('Highest rank reached'), findsOneWidget);
      final LinearProgressIndicator bar = tester.widget(find.byType(LinearProgressIndicator));
      expect(bar.value, 1);
    });

    testWidgets('freeze card: slots and full state ($mode)', (tester) async {
      svc.streakNotifier.value = StreakStatus.empty.copyWith(freezes: 1);
      await _pump(tester, theme, FreezeCard(onEarnCoins: () {}));
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.textContaining('Get one'), findsOneWidget);

      svc.streakNotifier.value = svc.streakNotifier.value.copyWith(freezes: 2);
      await tester.pump();
      expect(find.text('Full'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('freeze card: buy sheet shows balance after ($mode)', (tester) async {
      svc.balanceNotifier.value = 240;
      await _pump(tester, theme, FreezeCard(onEarnCoins: () {}));
      await tester.tap(find.textContaining('Get one'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Buy a streak freeze for 50 coins?'), findsOneWidget);
      expect(find.text('Balance after: 190'), findsOneWidget);
      expect(find.text('Buy'), findsOneWidget);
    });

    testWidgets('freeze card: not enough coins asks to earn ($mode)', (tester) async {
      svc.balanceNotifier.value = 20;
      int earned = 0;
      await _pump(tester, theme, FreezeCard(onEarnCoins: () => earned++));
      await tester.tap(find.textContaining('Get one'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('You need 50 coins.'), findsOneWidget);
      await tester.tap(find.text('Earn coins'));
      await tester.pump(const Duration(seconds: 1));
      expect(earned, 1);
    });

    testWidgets('balance card ($mode)', (tester) async {
      svc.balanceNotifier.value = 240;
      int taps = 0;
      await _pump(tester, theme, BalanceCard(onSeeUses: () => taps++));
      expect(find.text('240'), findsOneWidget);
      await tester.tap(find.text('What you can do with them'));
      expect(taps, 1);
      expect(find.text('See Pro'), findsOneWidget);
    });
  }

  testWidgets('freeze button sits at the right edge of the card at normal width', (tester) async {
    await _pump(tester, ThemeData.dark(), FreezeCard(onEarnCoins: () {}));
    final double cardRight = tester.getTopRight(find.byType(FreezeCard)).dx;
    final double buttonRight = tester.getTopRight(find.byType(FilledButton)).dx;
    expect(cardRight - buttonRight, closeTo(18, 0.01));
  });

  for (final ThemeData theme in <ThemeData>[kLightTheme, kDarkTheme]) {
    testWidgets('freeze button folds to the left at 320px and text scale 1.3 (${theme.brightness.name})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FreezeCard(onEarnCoins: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final Rect card = tester.getRect(find.byType(FreezeCard));
      final Rect button = tester.getRect(find.byType(FilledButton));
      final Rect slot = tester.getRect(find.byIcon(Icons.ac_unit_rounded).last);
      expect(button.top, greaterThan(slot.bottom));
      expect(button.left - card.left, closeTo(18, 0.01));
      expect(button.right, lessThanOrEqualTo(card.right - 18));
      expect(button.bottom, lessThanOrEqualTo(card.bottom - 18));
    });
  }
}
