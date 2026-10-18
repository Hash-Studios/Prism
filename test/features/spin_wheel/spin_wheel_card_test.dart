import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/features/spin_wheel/views/widgets/spin_wheel_card.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../qa_render/qa_harness.dart' show loadFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadFonts);

  Future<void> pumpCard(WidgetTester tester, SpinWheelStatus status, {List<WheelSegment>? segments}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SpinWheelCard(status: ValueNotifier<SpinWheelStatus>(status), segments: segments, onOpen: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a Pro user with a free spin sees the ready line and a Free spin button', (tester) async {
    await pumpCard(tester, const SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 5, price: 10));

    expect(find.text('Spin the wheel'), findsOneWidget);
    expect(find.text('Your free spin is ready'), findsOneWidget);
    expect(find.text('Free spin'), findsOneWidget);
    expect(find.text('Spin'), findsNothing);
  });

  testWidgets('everyone else sees the price, the best prize and a Spin button', (tester) async {
    await pumpCard(tester, const SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 3, price: 10));

    expect(find.text('10 coins a spin. Win up to 100 coins, XP or a cosmetic'), findsOneWidget);
    expect(find.text('Spin'), findsOneWidget);
    expect(find.text('Free spin'), findsNothing);
  });

  testWidgets('the best prize and the price follow the wheel and the status', (tester) async {
    await pumpCard(
      tester,
      const SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 2, price: 12),
      segments: const <WheelSegment>[
        WheelSegment(CoinsPrize(30), weight: 1),
        WheelSegment(CoinsPrize(250), weight: 1),
        WheelSegment(XpPrize(500), weight: 1),
      ],
    );

    expect(find.text('12 coins a spin. Win up to 250 coins, XP or a cosmetic'), findsOneWidget);
  });

  testWidgets('with no spins left it says Back tomorrow and has no button', (tester) async {
    await pumpCard(tester, const SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 0, price: 10));

    expect(find.text('Back tomorrow'), findsOneWidget);
    expect(find.text('Spin'), findsNothing);
    expect(find.text('Free spin'), findsNothing);
  });

  testWidgets('tapping the card or the button opens the machine', (tester) async {
    int opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        home: Scaffold(
          body: SpinWheelCard(
            status: ValueNotifier<SpinWheelStatus>(
              const SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 5, price: 10),
            ),
            onOpen: () => opened++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Spin the wheel'));
    expect(opened, 1);
    await tester.tap(find.text('Spin'));
    expect(opened, 2);
  });

  testWidgets('with no spins left, the card still opens the machine', (tester) async {
    int opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        home: Scaffold(
          body: SpinWheelCard(
            status: ValueNotifier<SpinWheelStatus>(
              const SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 0, price: 10),
            ),
            onOpen: () => opened++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Spin the wheel'));
    expect(opened, 1);
  });

  testWidgets('the card follows the status without a rebuild from the parent', (tester) async {
    final ValueNotifier<SpinWheelStatus> status = ValueNotifier<SpinWheelStatus>(
      const SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 5, price: 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        home: Scaffold(
          body: SpinWheelCard(status: status, onOpen: () {}),
        ),
      ),
    );
    expect(find.text('Your free spin is ready'), findsOneWidget);

    status.value = const SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 5, price: 10);
    await tester.pump();
    expect(find.text('Your free spin is ready'), findsNothing);
    expect(find.text('Spin'), findsOneWidget);
  });
}
