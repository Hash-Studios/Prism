import 'package:Prism/core/coins/coins_service.dart';
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
