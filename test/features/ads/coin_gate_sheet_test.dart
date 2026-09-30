import 'package:Prism/features/ads/views/widgets/coin_gate_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('coin gate preserves its shape and returns the chosen option', (tester) async {
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                answer = await showCoinGateSheet<String>(
                  context,
                  title: 'Download',
                  cost: 0,
                  message: (_) => 'Choose an option',
                  options: const [CoinGateOption(label: 'Continue', value: 'download')],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.text('Choose an option')))! as ModalBottomSheetRoute;
    expect(route.useSafeArea, isFalse);
    expect(route.shape, const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(answer, 'download');
  });
}
