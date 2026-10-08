import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final CoinsService coins = CoinsService.instance;
  late bool wasLoggedIn;

  setUp(() {
    wasLoggedIn = app_state.prismUser.loggedIn;
    app_state.prismUser.loggedIn = true;
    coins.balanceNotifier.value = 120;
    coins.deltaNotifier.value = 0;
  });

  tearDown(() {
    app_state.prismUser.loggedIn = wasLoggedIn;
    coins.deltaNotifier.value = 0;
  });

  Widget host({bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const Scaffold(body: CoinBalanceChip(sourceTag: 'test', showStreak: false)),
    ),
  );

  testWidgets('the label reads the balance, and adds the change while one is showing', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());
    expect(find.bySemanticsLabel('120 Prism coins'), findsOneWidget);

    coins.deltaNotifier.value = 5;
    await tester.pump();
    expect(find.bySemanticsLabel('120 Prism coins, up 5'), findsOneWidget);

    coins.deltaNotifier.value = -3;
    await tester.pump();
    expect(find.bySemanticsLabel('120 Prism coins, down 3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the pulse is skipped when reduce motion is on', (tester) async {
    coins.deltaNotifier.value = 5;
    await tester.pumpWidget(host(reduceMotion: true));

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, Duration.zero);
  });

  testWidgets('the pulse animates when reduce motion is off', (tester) async {
    coins.deltaNotifier.value = 5;
    await tester.pumpWidget(host());

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, const Duration(milliseconds: 220));
  });
}
