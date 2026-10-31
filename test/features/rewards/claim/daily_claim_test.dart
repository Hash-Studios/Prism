import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ads/views/widgets/coin_gate_sheet.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/rewards/views/widgets/daily_claim_host.dart';
import 'package:Prism/features/rewards/views/widgets/daily_claim_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/coins_test_backend.dart';

StreakClaimResult _r({
  int day = 3,
  int count = 3,
  bool broken = false,
  int freezesUsed = 0,
  bool week = false,
  int? milestone,
  int daily = 8,
  int bonus = 0,
  bool? chest,
}) => StreakClaimResult(
  claimed: true,
  alreadyClaimedToday: false,
  streakDay: day,
  streakCount: count,
  previousStreakCount: 9,
  streakBest: count,
  streakBroken: broken,
  freezesUsed: freezesUsed,
  freezesLeft: 1,
  isWeekComplete: week,
  dailyReward: daily,
  streakBonusReward: bonus,
  proBonusReward: 0,
  totalReward: daily + bonus,
  newBalance: 100,
  milestone: milestone,
  isChest: chest ?? (week && bonus > 0),
);

Widget _app(ThemeData theme, Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  theme: theme,
  home: Scaffold(body: home),
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final List<ThemeData> _themes = [ThemeData.light(), ThemeData.dark()];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();

  setUpAll(() async {
    await (FontLoader('Proxima Nova')
          ..addFont(rootBundle.load('assets/fonts/ProximaNova-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/Proxima Nova Bold.otf'))
          ..addFont(rootBundle.load('assets/fonts/Proxima Nova Extrabold.otf')))
        .load();
    await (FontLoader('Fraunces')..addFont(rootBundle.load('assets/fonts/Fraunces-Variable.ttf'))).load();
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    CoinsService.instance.resetSession();
    await getIt.reset();
  });

  testWidgets('week-complete sheet does not overflow at 320x568 with text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => showDailyClaimSheet(c, _r(day: 7, count: 7, week: true, bonus: 40)),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(AppLocalizationsEn().economySeeRewards),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(AppLocalizationsEn().economyNice), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('claim sheet variants keep both actions reachable at 320px and text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool sawRewards = false;
    StreakClaimResult current = _r();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDailyClaimSheet(context, current, onSeeRewards: () => sawRewards = true),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    for (final StreakClaimResult result in <StreakClaimResult>[
      _r(),
      _r(day: 7, count: 7, week: true, bonus: 40),
      _r(broken: true, daily: 5),
      _r(freezesUsed: 1, count: 20),
      _r(milestone: 30),
    ]) {
      current = result;
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      final Finder primary = find.text(
        result.streakBroken ? AppLocalizationsEn().actionDone : AppLocalizationsEn().economyNice,
      );
      await tester.ensureVisible(primary);
      expect(primary, findsOneWidget);
      await tester.tap(primary);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final Finder secondary = find.text(
        result.streakBroken ? AppLocalizationsEn().economyGetFreezeNextTime : AppLocalizationsEn().economySeeRewards,
      );
      await tester.ensureVisible(secondary);
      expect(secondary, findsOneWidget);
      await tester.tap(secondary);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }
    expect(sawRewards, isTrue);
  });

  for (final ThemeData theme in _themes) {
    testWidgets('claim sheet variants (${theme.brightness.name})', (tester) async {
      _tall(tester);
      Future<void> open(StreakClaimResult r) async {
        await tester.pumpWidget(
          _app(
            theme,
            Builder(
              builder: (c) => TextButton(onPressed: () => showDailyClaimSheet(c, r), child: const Text('go')),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
      }

      Future<void> close() async {
        await tester.tap(
          find.text(AppLocalizationsEn().economyNice).evaluate().isEmpty
              ? find.text(AppLocalizationsEn().actionDone)
              : find.text(AppLocalizationsEn().economyNice),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      await open(_r());
      expect(find.text(AppLocalizationsEn().economyDayLabel(3)), findsNWidgets(2));
      expect(find.text('+${formatLocalizedNumber(8, AppLocalizationsEn())}'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().economySeeRewards), findsOneWidget);

      await close();
      await open(_r(day: 7, count: 14, week: true, daily: 10, bonus: 30));
      expect(find.text(AppLocalizationsEn().economyDay7Chest), findsOneWidget);
      expect(
        find.text(
          '${AppLocalizationsEn().economyStreakDailyReward(10)} · '
          '${AppLocalizationsEn().economyStreakChestReward(30)}',
        ),
        findsOneWidget,
      );

      await close();
      await open(_r(day: 7, count: 14, week: true, daily: 10));
      expect(find.text(AppLocalizationsEn().economyWeekComplete), findsOneWidget);

      await close();
      await open(_r(day: 7, count: 14, week: true, daily: 10, bonus: 30, chest: false));
      expect(find.text(AppLocalizationsEn().economyWeekComplete), findsOneWidget);
      expect(find.text(AppLocalizationsEn().economyDay7Chest), findsNothing);

      await close();
      await open(_r(broken: true, daily: 5));
      expect(find.text(AppLocalizationsEn().economyStreakReset), findsOneWidget);
      expect(find.text(AppLocalizationsEn().actionDone), findsOneWidget);
      expect(find.text(AppLocalizationsEn().economyGetFreezeNextTime), findsOneWidget);

      await close();
      await open(_r(freezesUsed: 1, count: 20));
      expect(find.text(AppLocalizationsEn().economyStreakFreezeSaved(20)), findsOneWidget);
      expect(find.text(AppLocalizationsEn().economyStreakFreezesLeft(1)), findsOneWidget);

      await close();
      await open(_r(milestone: 30));
      expect(find.text(AppLocalizationsEn().economyDayStreakMilestone(30)), findsOneWidget);
    });
  }

  testWidgets('See rewards calls back after close', (tester) async {
    _tall(tester);
    bool called = false;
    await tester.pumpWidget(
      _app(
        ThemeData.dark(),
        Builder(
          builder: (c) => TextButton(
            onPressed: () => showDailyClaimSheet(c, _r(), onSeeRewards: () => called = true),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text(AppLocalizationsEn().economySeeRewards));
    await tester.pump(const Duration(seconds: 1));
    expect(called, isTrue);
  });

  testWidgets('claim animation settles when reduce motion is enabled while running', (tester) async {
    final reduce = ValueNotifier<bool>(false);
    addTearDown(reduce.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: reduce,
          builder: (context, reduced, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(onPressed: () => showDailyClaimSheet(c, _r()), child: const Text('go')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('+8'), findsNothing);
    reduce.value = true;
    await tester.pump();
    expect(find.text('+8'), findsOneWidget);
  });

  testWidgets('host shows sheet once and consumes claim', (tester) async {
    _tall(tester);
    DailyMomentConfig.enabledOverride = false;
    addTearDown(() => DailyMomentConfig.enabledOverride = null);
    await backend.install();
    backend.onCall = (_, _) async => <String, Object>{
      ...CoinsTestBackend.claimPayload,
      'todayLocalKey': DateTime.now().toUtc().toIso8601String().substring(0, 10),
      'timezoneOffsetMinutes': 0,
    };
    addTearDown(getIt.reset);
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
    await tester.pumpWidget(
      _app(ThemeData.dark(), DailyClaimSheetHost(onSeeRewards: () {}, child: const Text('home'))),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(CoinsService.instance.lastClaimNotifier.value, isNull);
    expect(find.text(AppLocalizationsEn().economyNice), findsOneWidget);
    await tester.tap(find.text(AppLocalizationsEn().economyNice));
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(AppLocalizationsEn().economyNice), findsNothing);
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  testWidgets('guest and next account never see the previous account claim', (tester) async {
    DailyMomentConfig.enabledOverride = false;
    addTearDown(() => DailyMomentConfig.enabledOverride = null);
    await backend.install();
    backend.onCall = (_, _) async => <String, Object>{
      ...CoinsTestBackend.claimPayload,
      'todayLocalKey': DateTime.now().toUtc().toIso8601String().substring(0, 10),
      'timezoneOffsetMinutes': 0,
    };
    addTearDown(getIt.reset);
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
    expect(CoinsService.instance.pendingClaimForCurrentUser, isNotNull);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await tester.pumpWidget(
      _app(ThemeData.light(), DailyClaimSheetHost(onSeeRewards: () {}, child: const Text('home'))),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(AppLocalizationsEn().economyNice), findsNothing);
    expect(CoinsService.instance.lastClaimNotifier.value, isNull);

    CoinsService.instance.resetSession();
    await backend.install();
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
    expect(CoinsService.instance.pendingClaimForCurrentUser, isNotNull);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'other-${backend.userId}'
      ..loggedIn = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(AppLocalizationsEn().economyNice), findsNothing);
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  testWidgets('covered route delays claim until pop and already-claimed never queues', (tester) async {
    _tall(tester);
    DailyMomentConfig.enabledOverride = false;
    addTearDown(() => DailyMomentConfig.enabledOverride = null);
    await backend.install();
    backend.onCall = (_, _) async => <String, Object>{
      ...CoinsTestBackend.claimPayload,
      'todayLocalKey': DateTime.now().toUtc().toIso8601String().substring(0, 10),
      'timezoneOffsetMinutes': 0,
    };
    addTearDown(getIt.reset);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        navigatorKey: navigator,
        home: DailyClaimSheetHost(
          onSeeRewards: () {},
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('detail'))));
    await tester.pumpAndSettle();
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(AppLocalizationsEn().economyNice), findsNothing);
    expect(CoinsService.instance.lastClaimNotifier.value, isNotNull);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text(AppLocalizationsEn().economyNice), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pump(const Duration(seconds: 1));
    backend.onCall = (_, _) async => <String, Object>{
      ...CoinsTestBackend.claimPayload,
      'claimed': false,
      'alreadyClaimedToday': true,
    };
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(AppLocalizationsEn().economyNice), findsNothing);
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  testWidgets('coin gate shows Earn coins when short', (tester) async {
    CoinsService.instance.balanceNotifier.value = 0;
    await tester.pumpWidget(
      _app(
        ThemeData.light(),
        Builder(
          builder: (c) => TextButton(
            onPressed: () => showCoinGateSheet<int>(
              c,
              title: 'Low coin balance',
              cost: 5,
              message: (m) => 'You need $m more coins.',
              options: const [CoinGateOption(label: 'Upgrade', value: 1)],
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(AppLocalizationsEn().economyGetCoins), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
  });
}
