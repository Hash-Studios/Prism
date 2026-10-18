import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
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

  Future<FakeQuestsRepository> pumpCard(
    WidgetTester tester,
    QuestState? quests, {
    VoidCallback? onOpenProSpin,
    Brightness brightness = Brightness.light,
  }) async {
    final FakeQuestsRepository repo = FakeQuestsRepository(quests: quests);
    getIt.registerFactory<QuestsBloc>(() => QuestsBloc(repo));
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? kLightTheme : kDarkTheme,
        home: Scaffold(
          body: SingleChildScrollView(child: TodayCard(onOpenProSpin: onOpenProSpin)),
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

  testWidgets('shows nothing until the quests load', (tester) async {
    await pumpCard(tester, null);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('locked: shows the three quests with progress, the bonus row and the weekly row', (tester) async {
    final FakeQuestsRepository repo = await pumpCard(tester, questState());

    expect(repo.refreshes, 1);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('0 of 3 done'), findsOneWidget);
    expect(find.text('Set or save a wallpaper'), findsOneWidget);
    expect(find.text('Favourite 3 walls'), findsOneWidget);
    expect(find.textContaining('1 of 3'), findsOneWidget);
    expect(find.textContaining('+${CoinPolicy.questCoins} coins · +25 XP'), findsNWidgets(3));
    expect(find.text('Watch a video (+${CoinsService.instance.adsRewardNow})'), findsOneWidget);
    expect(find.text('Doubles your chest'), findsOneWidget);
    expect(find.text('Daily chest'), findsOneWidget);
    expect(find.textContaining('Finish 3 quests'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    expect(find.text('Save or set 5 walls'), findsOneWidget);
    expect(find.textContaining('This week · 2 of 5'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready: shows an Open button that opens the chest sheet', (tester) async {
    final FakeQuestsRepository repo = await pumpCard(tester, allClaimed());
    repo.chest = const ChestResult(ChestOutcome.opened, coins: 12);

    expect(find.text('3 of 3 done'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(repo.opens, 1);
    expect(find.text('Chest opened'), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
  });

  testWidgets('opened: the chest shows a check and no Open button', (tester) async {
    await pumpCard(tester, allClaimed(chestOpened: true));

    expect(find.text('Open'), findsNothing);
    expect(find.text('Opened. A new one tomorrow.'), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('doubled: the chest says it was doubled and the bonus row is done', (tester) async {
    await pumpCard(tester, allClaimed(chestOpened: true, chestDoubled: true));

    expect(find.text('Opened and doubled'), findsOneWidget);
    expect(find.text('Watch a video'), findsOneWidget);
    expect(find.text('Watch'), findsNothing);
  });

  testWidgets('a Pro bonus row opens the Pro spin card through the callback', (tester) async {
    int taps = 0;
    await pumpCard(tester, questState(bonus: questItem('pro_spin', QuestEvent.proSpin)), onOpenProSpin: () => taps++);

    expect(find.text('Open your Pro spin'), findsOneWidget);
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

  testWidgets('a failed chest shows an error toast', (tester) async {
    final FakeQuestsRepository repo = await pumpCard(tester, allClaimed());
    repo.chest = const ChestResult(ChestOutcome.failed);
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();

    expect(toasts, <String>["Couldn't open the chest. Try again."]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('quest rows use configured coins and XP without a standalone bonus XP award', (tester) async {
    await pumpCard(tester, questState());
    EconomyConfig.current = const EconomyConfig(
      award: EconomyAward(questCoins: 7, questXp: 41, weeklyQuestCoins: 90, weeklyQuestXp: 305),
    );
    await tester.pump();
    expect(find.textContaining('+7 coins · +41 XP'), findsNWidgets(3));
    expect(find.textContaining('+90 coins · +305 XP'), findsOneWidget);
    expect(find.text('Doubles your chest'), findsOneWidget);
    expect(find.textContaining('+0 XP'), findsNothing);
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

  for (final Brightness brightness in Brightness.values) {
    testWidgets('fits 320px at text scale 1.3 (${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final FakeQuestsRepository repo = FakeQuestsRepository(quests: allClaimed());
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
      await tester.pump();
      expect(tester.takeException(), isNull);
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
    await tester.pumpAndSettle();
    expect(repo.refreshes, 2);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(repo.refreshes, 3);
  });

  testWidgets('a quest row merges only its text; the trailing button keeps its own node', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCard(tester, allClaimed());

    expect(find.bySemanticsLabel('Set or save a wallpaper, done. +2 coins · +25 XP'), findsOneWidget);
    expect(find.bySemanticsLabel('Open'), findsOneWidget);
    handle.dispose();
  });
}
