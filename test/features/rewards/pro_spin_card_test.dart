import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/rewards/views/widgets/pro_spin_card.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> toasts = <String>[];

  setUp(() async {
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    await backend.install();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    CoinsService.instance.questsNotifier.value = null;
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> pumpCard(WidgetTester tester, {required bool pro}) async {
    app_state.prismUser.premium = pro;
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        home: const Scaffold(body: SingleChildScrollView(child: ProSpinCard())),
      ),
    );
    await tester.pump();
  }

  testWidgets('free users get one quiet row, no Spin button', (tester) async {
    await pumpCard(tester, pro: false);

    final range = proSpinRange();
    expect(find.text('Pro members spin daily for ${range.low} to ${range.high} coins'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('Spin'), findsNothing);
    expect(find.text('Pro spin'), findsNothing);
  });

  testWidgets('Pro users spin once and see the won amount count up, then Back tomorrow', (tester) async {
    final List<String> calls = <String>[];
    backend.onCall = (name, params) async {
      calls.add(name);
      if (name == 'reconcileRankRewards') {
        return <String, Object>{
          'success': true,
          'rev': 0,
          'owned': <String>[],
          'added': <String>[],
          'inventoryChanged': false,
        };
      }
      expect(name, 'claimProSpin');
      return <String, Object>{
        'success': true,
        'changed': true,
        'coins': 50,
        'segment': 2,
        'previousBalance': 100,
        'currentBalance': 150,
        'delta': 50,
        'reason': 'pro_spin',
      };
    };
    await pumpCard(tester, pro: true);

    final range = proSpinRange();
    expect(find.text('Pro spin'), findsOneWidget);
    expect(find.text('Once a day, ${range.low} to ${range.high} coins'), findsOneWidget);

    await tester.tap(find.text('Spin'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Spin'), findsNothing);
    await tester.pump(const Duration(seconds: 1));

    expect(calls.where((name) => name == 'claimProSpin'), hasLength(1));
    expect(calls, contains('reconcileRankRewards'));
    expect(find.text('+50 coins'), findsOneWidget);
    expect(find.text('Back tomorrow'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('an already claimed spin shows Back tomorrow without an amount', (tester) async {
    backend.onCall = (name, params) async => <String, Object>{
      'success': false,
      'changed': false,
      'reason': 'pro_spin_already_claimed',
    };
    await pumpCard(tester, pro: true);

    await tester.tap(find.text('Spin'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('Back tomorrow'), findsOneWidget);
    expect(find.textContaining('coins'), findsNothing);
  });

  QuestState spinClaimed(String dayKey) => QuestState(
    dayKey: dayKey,
    items: const <QuestItem>[],
    weekKey: '2026-W42',
    chestOpened: false,
    chestDoubled: false,
    bonus: const QuestItem(id: 'pro_spin', event: QuestEvent.proSpin, target: 1, progress: 1, claimed: true),
  );

  testWidgets('the card starts as done when the Pro spin bonus quest is claimed', (tester) async {
    CoinsService.instance.questsNotifier.value = spinClaimed(economyDayKey(DateTime.now()));
    await pumpCard(tester, pro: true);

    expect(find.text('Back tomorrow'), findsOneWidget);
    expect(find.text('Spin'), findsNothing);
  });

  testWidgets('a claimed bonus from an earlier UTC day does not mark the spin done', (tester) async {
    CoinsService.instance.questsNotifier.value = spinClaimed('2020-01-01');
    await pumpCard(tester, pro: true);

    expect(find.text('Spin'), findsOneWidget);
  });

  testWidgets('the odds sheet lists every segment with its share', (tester) async {
    await pumpCard(tester, pro: true);

    await tester.tap(find.text('See the odds'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Pro spin odds'), findsOneWidget);
    final double total = CoinPolicy.proSpin.fold<double>(0, (sum, s) => sum + s.weight);
    for (final s in CoinPolicy.proSpin) {
      expect(find.text('${s.coins} coins'), findsOneWidget);
      expect(find.text('${(s.weight / total * 100).round()}%'), findsWidgets);
    }
  });
}
