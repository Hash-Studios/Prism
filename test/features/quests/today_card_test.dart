import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/views/widgets/chest_banner.dart';
import 'package:Prism/features/quests/views/widgets/today_card.dart';
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
    EconomyConfig.resetForTest();
  });

  /// The chest animates forever once it is ready, so these tests pump fixed durations and never settle.
  Future<FakeQuestsRepository> pumpCard(
    WidgetTester tester,
    QuestState? quests, {
    VoidCallback? onOpenSpin,
    Brightness brightness = Brightness.light,
  }) async {
    final FakeQuestsRepository repo = FakeQuestsRepository(quests: quests);
    getIt.registerFactory<QuestsBloc>(() => QuestsBloc(repo));
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? kLightTheme : kDarkTheme,
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

  Finder resetCountdown() => find.byWidgetPredicate(
    (Widget w) => w is Text && RegExp(r'^New in (\d+d \d+h|\d+h \d+m|\d+m)$').hasMatch(w.data ?? ''),
  );

  testWidgets('shows nothing until the quests load', (tester) async {
    await pumpCard(tester, null);
    expect(find.text('Daily quests'), findsNothing);
  });

  testWidgets('locked: shows the header, the quest tiles, the locked chest and the weekly tile', (tester) async {
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
    expect(find.text('Daily quests'), findsOneWidget);
    expect(resetCountdown(), findsOneWidget);
    expect(find.bySemanticsLabel('Set or save a wallpaper, done. Pays 2 coins and 25 XP'), findsOneWidget);
    expect(find.bySemanticsLabel('Favourite 3 walls, 1 of 3. Pays 2 coins and 25 XP'), findsOneWidget);
    expect(find.bySemanticsLabel("Open today's Wall of the Day, 0 of 1. Pays 2 coins and 25 XP"), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Save or set 5 walls, 2 of 5\. Pays 30 coins and 150 XP\. This week, ends in (\d+d \d+h|\d+h \d+m|\d+m)$',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Daily chest'), findsOneWidget);
    expect(find.text('Finish 3 quests to open it'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Daily chest, locked. 1 of 3 quests done'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    expect(find.textContaining('Watch a video'), findsOneWidget);
    expect(find.text('Doubles your chest'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('ready: an Open button opens the chest sheet', (tester) async {
    final FakeQuestsRepository repo = await pumpCard(tester, allClaimed());
    repo.chest = const ChestResult(ChestOutcome.opened, coins: 12);

    expect(find.text('5 to 15 coins, maybe a cosmetic'), findsOneWidget);
    expect(find.text('Do this first to double your chest'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(repo.opens, 1);
    expect(find.text('Chest opened'), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
  });

  testWidgets('a locked chest answer shows an info toast', (tester) async {
    final FakeQuestsRepository repo = await pumpCard(tester, allClaimed());
    repo.chest = const ChestResult(ChestOutcome.locked);
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();

    expect(toasts, <String>['Finish your 3 quests to open the chest.']);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a failed chest shows an error toast', (tester) async {
    final FakeQuestsRepository repo = await pumpCard(tester, allClaimed());
    repo.chest = const ChestResult(ChestOutcome.failed);
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();

    expect(toasts, <String>["Couldn't open the chest. Try again."]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('opened: the chest shows a check, no Open button and no booster', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCard(tester, allClaimed(chestOpened: true));

    expect(find.text('Open'), findsNothing);
    expect(find.text('Opened. A new one tomorrow.'), findsOneWidget);
    expect(find.descendant(of: find.byType(ChestBanner), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
    expect(find.bySemanticsLabel('Daily chest, opened'), findsOneWidget);
    expect(find.text('Watch'), findsNothing);
    expect(find.text('Doubles your chest'), findsNothing);
    handle.dispose();
  });

  testWidgets('doubled: the chest says it opened doubled', (tester) async {
    await pumpCard(tester, allClaimed(chestOpened: true, chestDoubled: true));

    expect(find.text('Opened and doubled. A new one tomorrow.'), findsOneWidget);
    expect(find.text('Watch'), findsNothing);
  });

  testWidgets('a claimed booster on a ready chest says the chest is doubled', (tester) async {
    await pumpCard(tester, allClaimed(chestDoubled: true));

    expect(find.text('Chest doubled'), findsOneWidget);
    expect(find.text('Your bonus is done'), findsOneWidget);
    expect(find.text('Watch'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('a Pro booster opens the spin machine through the callback', (tester) async {
    int taps = 0;
    await pumpCard(tester, questState(bonus: questItem('pro_spin', QuestEvent.proSpin)), onOpenSpin: () => taps++);

    expect(find.text('Take your free spin'), findsOneWidget);
    await tester.tap(find.text('Spin'));
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

    expect(find.bySemanticsLabel(RegExp('Pays 7 coins and 41 XP')), findsNWidgets(3));
    expect(find.bySemanticsLabel(RegExp('Pays 90 coins and 305 XP')), findsOneWidget);
    expect(find.text('Doubles your chest'), findsOneWidget);
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
    expect(toasts, <String>['Quest done: +22 coins · +98 XP']);

    repo.awards.value = const <QuestAward>[QuestAward(id: 'set_wall', coins: 0, xp: 43)];
    await tester.pump();
    await tester.pump();
    expect(toasts.last, 'Quest done: +43 XP');
    await tester.pump(const Duration(seconds: 2));
  });

  final Map<String, QuestState> boards = <String, QuestState>{
    'locked': questState(),
    'ready': allClaimed(),
    'doubled': allClaimed(chestOpened: true, chestDoubled: true),
  };
  for (final Brightness brightness in Brightness.values) {
    for (final MapEntry<String, QuestState> board in boards.entries) {
      testWidgets('${board.key} fits 320px at text scale 1.3 (${brightness.name})', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final FakeQuestsRepository repo = FakeQuestsRepository(quests: board.value);
        getIt.registerFactory<QuestsBloc>(() => QuestsBloc(repo));
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light ? kLightTheme : kDarkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const Scaffold(body: SingleChildScrollView(child: TodayCard())),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      });
    }
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

  testWidgets('the chest text merges into one node and the Open button keeps its own', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCard(tester, allClaimed());

    expect(find.bySemanticsLabel('Set or save a wallpaper, done. Pays 2 coins and 25 XP'), findsOneWidget);
    expect(find.bySemanticsLabel('Daily chest, ready to open'), findsOneWidget);
    expect(find.bySemanticsLabel('Open'), findsOneWidget);
    handle.dispose();
  });
}
