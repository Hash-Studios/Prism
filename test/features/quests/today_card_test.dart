import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/daily_chest/daily_chest.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/views/widgets/chest_banner.dart';
import 'package:Prism/features/quests/views/widgets/today_card.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_quests_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> toasts = <String>[];

  setUp(() {
    toasts.clear();
    DailyMomentConfig.enabledOverride = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    await getIt.reset();
    DailyMomentConfig.enabledOverride = null;
    EconomyConfig.resetForTest();
  });

  /// The chest box loops while it can be opened, so these tests pump fixed durations and never settle.
  Future<FakeQuestsRepository> pumpCard(
    WidgetTester tester,
    QuestState? quests, {
    VoidCallback? onOpenSpin,
    Brightness brightness = Brightness.light,
    DateTime Function()? clock,
    List<NavigatorObserver> observers = const <NavigatorObserver>[],
  }) async {
    final FakeQuestsRepository repo = FakeQuestsRepository(quests: quests);
    getIt.registerFactory<QuestsBloc>(() => QuestsBloc(repo)..clock = clock ?? DateTime.now);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        theme: brightness == Brightness.light ? kLightTheme : kDarkTheme,
        navigatorObservers: observers,
        home: Scaffold(
          body: SingleChildScrollView(child: TodayCard(onOpenSpin: onOpenSpin)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return repo;
  }

  QuestState allClaimed({bool chestOpened = false, bool chestDoubled = false}) => questState(
    items: <QuestItem>[
      questItem('set_wall', QuestEvent.setWallpaper, claimed: true, progress: 1),
      questItem('fav_3', QuestEvent.favourite, target: 3, claimed: true, progress: 3),
      questItem('wotd_view', QuestEvent.viewWotd, claimed: true, progress: 1),
    ],
    bonus: questItem('watch_ad', QuestEvent.watchAd, claimed: chestDoubled, progress: chestDoubled ? 1 : 0),
    chestOpened: chestOpened,
    chestDoubled: chestDoubled,
  );

  /// The 88 square the box sits in; the box itself is larger, because the art has margins.
  Finder chestSlot() => find.ancestor(of: find.byType(ChestBox), matching: find.byType(OverflowBox));

  Finder resetCountdown() => find.byWidgetPredicate(
    (Widget w) => w is Text && RegExp(r'^New in (\d+d \d+h|\d+h \d+m|\d+m)$').hasMatch(w.data ?? ''),
  );

  testWidgets('shows nothing until the quests load', (tester) async {
    await pumpCard(tester, null);
    expect(find.text(AppLocalizationsEn().economyDailyQuests), findsNothing);
  });

  testWidgets('daily moment keeps quests quiet with actual reward feedback', (tester) async {
    DailyMomentConfig.enabledOverride = true;
    final FakeQuestsRepository repo = await pumpCard(tester, questState());
    expect(find.text('Quests'), findsOneWidget);
    expect(resetCountdown(), findsNothing);
    expect(find.byType(ChestBanner), findsNothing);
    repo.awards.value = const <QuestAward>[
      QuestAward(id: 'set_wall', coins: 4, xp: 17),
      QuestAward(id: 'weekly_set_5', coins: 18, xp: 81),
    ];
    await tester.pump();
    await tester.pump();
    expect(find.text(AppLocalizationsEn().economyQuestDoneMessage(4, 17)), findsOneWidget);
    expect(find.text(AppLocalizationsEn().economyQuestDoneMessage(18, 81)), findsOneWidget);
    expect(toasts, isEmpty);
    expect(repo.consumed, 1);
    expect(repo.awards.value, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(AppLocalizationsEn().economyQuestDoneMessage(4, 17)), findsOneWidget);

    // A new card shares the same repository, but must not replay delivered feedback.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: const Scaffold(body: SingleChildScrollView(child: TodayCard())),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(AppLocalizationsEn().economyQuestDoneMessage(4, 17)), findsNothing);
    expect(find.text(AppLocalizationsEn().economyQuestDoneMessage(18, 81)), findsNothing);
    expect(repo.consumed, 1);
  });

  testWidgets('daily moment clears delivered feedback when the board disappears', (tester) async {
    DailyMomentConfig.enabledOverride = true;
    final FakeQuestsRepository repo = await pumpCard(tester, questState());
    repo.awards.value = const <QuestAward>[QuestAward(id: 'set_wall', coins: 4, xp: 17)];
    await tester.pump();
    await tester.pump();
    final String message = AppLocalizationsEn().economyQuestDoneMessage(4, 17);
    expect(find.text(message), findsOneWidget);

    repo.quests.value = null;
    repo.quests.value = questState();
    await tester.pump();
    expect(find.text(message), findsNothing);
    expect(repo.awards.value, isEmpty);
  });

  testWidgets('daily moment keeps hidden awards pending until the card is visible', (tester) async {
    DailyMomentConfig.enabledOverride = true;
    final FakeQuestsRepository repo = await pumpCard(tester, questState());
    final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Other'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    repo.awards.value = const <QuestAward>[QuestAward(id: 'set_wall', coins: 4, xp: 17)];
    await tester.pump();
    await tester.pump();
    expect(repo.consumed, 0);
    expect(repo.awards.value, isNotEmpty);

    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.consumed, 1);
    expect(repo.awards.value, isEmpty);
    expect(find.text(AppLocalizationsEn().economyQuestDoneMessage(4, 17)), findsOneWidget);
  });

  testWidgets('daily moment clears feedback when the daily board expires', (tester) async {
    DailyMomentConfig.enabledOverride = true;
    DateTime now = DateTime.now();
    final FakeQuestsRepository repo = await pumpCard(tester, questState(), clock: () => now);
    repo.awards.value = const <QuestAward>[QuestAward(id: 'set_wall', coins: 4, xp: 17)];
    await tester.pump();
    await tester.pump();
    final String message = AppLocalizationsEn().economyQuestDoneMessage(4, 17);
    expect(find.text(message), findsOneWidget);

    now = now.add(const Duration(days: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text(message), findsNothing);
    now = DateTime.now();
    repo.quests.value = questState();
    await tester.pump();
    expect(find.text(message), findsNothing);
  });

  testWidgets('paid: shows the header, the quest tiles, the chest with its price and the weekly tile', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final FakeQuestsRepository repo = await pumpCard(
      tester,
      questState(
        items: <QuestItem>[
          questItem('set_wall', QuestEvent.setWallpaper, claimed: true, progress: 1),
          questItem('fav_3', QuestEvent.favourite, target: 3, progress: 1),
          questItem('wotd_view', QuestEvent.viewWotd),
        ],
      ),
    );

    expect(repo.refreshes, 1);
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(find.text(l10n.economyDailyQuests), findsOneWidget);
    expect(resetCountdown(), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        l10n.economyQuestTileSemantics(
          l10n.economyQuestSetWall,
          'true',
          1,
          1,
          2,
          25,
          'true',
          'true',
          'false',
          '',
          'false',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        l10n.economyQuestTileSemantics(
          l10n.economyQuestFav3,
          'false',
          1,
          3,
          2,
          25,
          'true',
          'true',
          'false',
          '',
          'false',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        l10n.economyQuestTileSemantics(
          l10n.economyQuestWotd,
          'false',
          0,
          1,
          2,
          25,
          'true',
          'true',
          'false',
          '',
          'false',
        ),
      ),
      findsOneWidget,
    );
    final String weeklySemanticsPrefix = l10n.economyQuestTileSemantics(
      l10n.economyQuestWeeklySet5,
      'false',
      2,
      5,
      30,
      150,
      'true',
      'true',
      'true',
      '',
      'true',
    );
    expect(
      find.bySemanticsLabel(RegExp('^${RegExp.escape(weeklySemanticsPrefix)}' + r'(\d+d \d+h|\d+h \d+m|\d+m)$')),
      findsOneWidget,
    );
    expect(find.text(l10n.economyDailyChestTitle), findsOneWidget);
    expect(find.text(l10n.economyChestPriceFreeAfter(CoinPolicy.dailyChestPrice, 2)), findsOneWidget);
    expect(find.text(l10n.economyChestXpLine(10)), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        l10n.economyDailyChestSemantics(
          l10n.economyChestReadyPaid(1, 3),
          l10n.economyChestPriceFreeAfter(8, 2),
          'true',
          l10n.economyChestXpLine(10),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Finish 3 quests to open it'), findsNothing);
    expect(find.text(AppLocalizationsEn().economyWatchVideo), findsOneWidget);
    expect(find.text('Do this first to double your chest'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('paid: the chest is a box that loops in an 88 slot, and the pips count the quests done', (tester) async {
    await pumpCard(
      tester,
      questState(
        items: <QuestItem>[
          questItem('set_wall', QuestEvent.setWallpaper, claimed: true, progress: 1),
          questItem('fav_3', QuestEvent.favourite, target: 3, progress: 1),
          questItem('wotd_view', QuestEvent.viewWotd),
        ],
      ),
    );

    final ChestBox box = tester.widget<ChestBox>(find.byType(ChestBox));
    expect(box.phase, ChestPhase.ready);
    expect(box.still, isFalse);
    expect(tester.getSize(chestSlot()), const Size.square(88));
    final Iterable<double> pips = tester
        .widgetList<AnimatedOpacity>(
          find.descendant(of: find.byType(ChestBanner), matching: find.byType(AnimatedOpacity)),
        )
        .map((AnimatedOpacity o) => o.opacity);
    expect(pips, <double>[1, 0, 0]);
  });

  testWidgets('paid: one quest left is said in the singular', (tester) async {
    await pumpCard(
      tester,
      questState(
        items: <QuestItem>[
          questItem('set_wall', QuestEvent.setWallpaper, claimed: true, progress: 1),
          questItem('fav_3', QuestEvent.favourite, target: 3, claimed: true, progress: 3),
          questItem('wotd_view', QuestEvent.viewWotd),
        ],
      ),
    );

    expect(find.text('${CoinPolicy.dailyChestPrice} coins, or free after 1 more quest'), findsOneWidget);
  });

  testWidgets('paid: the chest takes the price from the economy config', (tester) async {
    await pumpCard(tester, questState());
    EconomyConfig.current = const EconomyConfig(spend: EconomySpend(dailyChest: 12));
    await tester.pump();

    expect(find.text(AppLocalizationsEn().economyChestPriceFreeAfter(12, 3)), findsOneWidget);
  });

  testWidgets('free: the chest is free today, with its XP, and the box still loops', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCard(tester, allClaimed());

    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(find.text(l10n.economyChestFreeToday), findsOneWidget);
    expect(find.text(l10n.economyChestXpLine(10)), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        l10n.economyDailyChestSemantics(
          l10n.economyChestReady,
          l10n.economyChestFreeToday,
          'true',
          l10n.economyChestXpLine(10),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.economyChestDoFirst), findsOneWidget);
    final ChestBox box = tester.widget<ChestBox>(find.byType(ChestBox));
    expect(box.phase, ChestPhase.ready);
    expect(tester.getSize(chestSlot()), const Size.square(88));
    handle.dispose();
  });

  testWidgets('a chest with no XP configured says nothing about XP', (tester) async {
    await pumpCard(tester, allClaimed());
    EconomyConfig.current = const EconomyConfig(xp: EconomyXp(activities: EconomyXpActivities(questChest: 0)));
    await tester.pump();

    expect(find.text(AppLocalizationsEn().economyChestFreeToday), findsOneWidget);
    expect(find.textContaining('XP.'), findsNothing);
  });

  testWidgets('Open opens the daily chest page over the app, for a paid or a free chest', (tester) async {
    for (final QuestState quests in <QuestState>[questState(), allClaimed()]) {
      CoinsService.instance.questsNotifier.value = quests;
      addTearDown(() => CoinsService.instance.questsNotifier.value = null);
      final _Pushes pushes = _Pushes();
      await pumpCard(tester, quests, observers: <NavigatorObserver>[pushes]);

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(pushes.names, contains('DailyChest'));
      expect(find.byType(DailyChestPage), findsOneWidget);
      await getIt.reset();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('opened: the chest shows a spent box, a check, no Open button and no booster', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCard(tester, allClaimed(chestOpened: true));

    expect(find.text('Open'), findsNothing);
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(find.text(l10n.economyChestOpenedTomorrow), findsOneWidget);
    expect(find.textContaining('XP.'), findsNothing);
    expect(find.descendant(of: find.byType(ChestBanner), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        l10n.economyDailyChestSemantics(l10n.economyChestOpened, l10n.economyChestOpenedTomorrow, 'false', ''),
      ),
      findsOneWidget,
    );
    final ChestBox box = tester.widget<ChestBox>(find.byType(ChestBox));
    expect(box.phase, ChestPhase.spent);
    expect(tester.getSize(chestSlot()), const Size.square(88));
    expect(find.text('Watch'), findsNothing);
    expect(find.text(AppLocalizationsEn().economyChestDoFirst), findsNothing);
    handle.dispose();
  });

  testWidgets('doubled: the chest says it opened doubled', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCard(tester, allClaimed(chestOpened: true, chestDoubled: true));

    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(find.text(l10n.economyChestOpenedDoubledTomorrow), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        l10n.economyDailyChestSemantics(l10n.economyChestOpened, l10n.economyChestOpenedDoubledTomorrow, 'false', ''),
      ),
      findsOneWidget,
    );
    expect(find.text('Watch'), findsNothing);
    handle.dispose();
  });

  testWidgets('a claimed booster on a free chest says the chest is doubled', (tester) async {
    await pumpCard(tester, allClaimed(chestDoubled: true));

    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(find.text(l10n.economyChestDoubled), findsOneWidget);
    expect(find.text(l10n.economyChestBonusDone), findsOneWidget);
    expect(find.text('Watch'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('a Pro booster opens the spin machine through the callback', (tester) async {
    int taps = 0;
    await pumpCard(tester, questState(bonus: questItem('pro_spin', QuestEvent.proSpin)), onOpenSpin: () => taps++);

    expect(find.text('Take your free spin'), findsOneWidget);
    await tester.tap(find.text(AppLocalizationsEn().economySpin));
    expect(taps, 1);
  });

  testWidgets('a paid quest award shows one toast and is consumed', (tester) async {
    final FakeQuestsRepository repo = await pumpCard(tester, questState());
    repo.awards.value = const <QuestAward>[QuestAward(id: 'set_wall', coins: 2, xp: 25)];
    await tester.pump();
    await tester.pump();

    expect(repo.consumed, 1);
    expect(toasts, <String>['Quest done: +2 coins · +25 XP']);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('quest tiles use the configured coins and XP', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCard(tester, questState());
    EconomyConfig.current = const EconomyConfig(
      award: EconomyAward(questCoins: 7, questXp: 41, weeklyQuestCoins: 90, weeklyQuestXp: 305),
    );
    await tester.pump();

    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(
      find.bySemanticsLabel(
        RegExp(
          RegExp.escape(
            l10n
                .economyQuestTileSemantics('', '', 0, 0, 7, 41, 'true', 'true', 'false', '', 'false')
                .split('. ')
                .skip(1)
                .join('. '),
          ),
        ),
      ),
      findsNWidgets(3),
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          RegExp.escape(
            l10n
                .economyQuestTileSemantics('', '', 0, 0, 90, 305, 'true', 'true', 'false', '', 'false')
                .split('. ')
                .skip(1)
                .join('. '),
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.economyChestDoFirst), findsOneWidget);
    handle.dispose();
  });

  testWidgets('completion feedback sums actual server awards, including XP-only rewards', (tester) async {
    final FakeQuestsRepository repo = await pumpCard(tester, questState());
    repo.awards.value = const <QuestAward>[
      QuestAward(id: 'set_wall', coins: 4, xp: 17),
      QuestAward(id: 'weekly_set_5', coins: 18, xp: 81),
      QuestAward(id: 'watch_ad', coins: 0, xp: 0),
    ];
    await tester.pump();
    await tester.pump();
    expect(toasts, <String>[AppLocalizationsEn().economyQuestDoneMessage(22, 98)]);

    repo.awards.value = const <QuestAward>[QuestAward(id: 'set_wall', coins: 0, xp: 43)];
    await tester.pump();
    await tester.pump();
    expect(toasts.last, 'Quest done: +43 XP');
    await tester.pump(const Duration(seconds: 2));
  });

  final Map<String, QuestState> boards = <String, QuestState>{
    'paid': questState(),
    'free': allClaimed(),
    'doubled': allClaimed(chestOpened: true, chestDoubled: true),
  };
  Future<void> pumpScaled(
    WidgetTester tester,
    QuestState quests,
    Brightness brightness, {
    required double width,
    required double textScale,
  }) async {
    tester.view.physicalSize = Size(width, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FakeQuestsRepository repo = FakeQuestsRepository(quests: quests);
    getIt.registerFactory<QuestsBloc>(() => QuestsBloc(repo));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        theme: brightness == Brightness.light ? kLightTheme : kDarkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: SingleChildScrollView(child: TodayCard())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final Brightness brightness in Brightness.values) {
    for (final MapEntry<String, QuestState> board in boards.entries) {
      testWidgets('${board.key} fits 320px at text scale 1.3 (${brightness.name})', (tester) async {
        await pumpScaled(tester, board.value, brightness, width: 320, textScale: 1.3);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('paid fits 390px at text scale 2.4 (${brightness.name})', (tester) async {
      await pumpScaled(tester, boards['paid']!, brightness, width: 390, textScale: 2.4);
      expect(tester.takeException(), isNull);
      expect(find.text(AppLocalizationsEn().economyDailyQuests), findsOneWidget);
    });
  }

  testWidgets('syncs again on resume and when the card shows again after a pushed route', (tester) async {
    final FakeQuestsRepository repo = await pumpCard(tester, questState());
    expect(repo.refreshes, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repo.refreshes, 2);

    final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Other'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.refreshes, 2);
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.refreshes, 3);
  });

  group('the minute check', () {
    final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));

    Future<FakeQuestsRepository> pumpYesterdaysCard(WidgetTester tester) =>
        pumpCard(tester, questState(dayKey: economyDayKey(yesterday)), clock: () => yesterday);

    testWidgets('syncs again once the quests are for an earlier day', (tester) async {
      final FakeQuestsRepository repo = await pumpYesterdaysCard(tester);
      expect(repo.refreshes, 1);

      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(repo.refreshes, 2);
    });

    testWidgets('hides the board while the quests are for an earlier day', (tester) async {
      await pumpYesterdaysCard(tester);

      expect(find.text('Daily quests'), findsNothing);
      expect(find.byType(ChestBox), findsNothing);
    });

    testWidgets('does nothing while another page covers the card', (tester) async {
      final FakeQuestsRepository repo = await pumpYesterdaysCard(tester);
      final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Other'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(repo.refreshes, 1);
    });
  });

  testWidgets('the chest text merges into one node and the Open button keeps its own', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCard(tester, allClaimed());

    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(
      find.bySemanticsLabel(
        l10n.economyQuestTileSemantics(
          l10n.economyQuestSetWall,
          'true',
          1,
          1,
          2,
          25,
          'true',
          'true',
          'false',
          '',
          'false',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        l10n.economyDailyChestSemantics(
          l10n.economyChestReady,
          l10n.economyChestFreeToday,
          'true',
          l10n.economyChestXpLine(10),
        ),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(l10n.economyOpen), findsOneWidget);
    handle.dispose();
  });
}

class _Pushes extends NavigatorObserver {
  final List<String?> names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => names.add(route.settings.name);
}
