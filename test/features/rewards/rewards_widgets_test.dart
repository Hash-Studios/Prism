import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/features/rewards/views/widgets/balance_card.dart';
import 'package:Prism/features/rewards/views/widgets/freeze_card.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  await tester.pumpWidget(_app(theme, child));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  final CoinsService svc = CoinsService.instance;
  final int balance = svc.balanceNotifier.value;

  tearDown(() {
    svc.streakNotifier.value = StreakStatus.empty;
    svc.balanceNotifier.value = balance;
  });

  testWidgets('standalone guest rewards can navigate back while tab has no back button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: RewardsTabPage()));
    await tester.pump();
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('freeze sheet tracks balance changes while open', (tester) async {
    svc.balanceNotifier.value = 20;
    await _pump(tester, ThemeData.light(), FreezeCard(onEarnCoins: () {}));
    await tester.tap(find.textContaining('Get one'));
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
      expect(find.text('Finish day 7 for a +40 week bonus'), findsOneWidget);
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
}
