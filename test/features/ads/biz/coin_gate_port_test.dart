import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:Prism/features/ads/biz/coin_gate_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AdsBloc lookup is deferred until a rewarded ad is requested', () {
    bool lookedUp = false;
    final AppCoinGatePort port = AppCoinGatePort(() {
      lookedUp = true;
      throw StateError('AdsBloc unavailable');
    });

    expect(lookedUp, isFalse);
    expect(() => port.watchRewardedAdResult(), throwsStateError);
    expect(lookedUp, isTrue);
  });

  testWidgets('premium gate runs in a context without an AdsBloc', (WidgetTester tester) async {
    final bool previousPremium = app_state.prismUser.premium;
    addTearDown(() {
      app_state.prismUser.premium = previousPremium;
    });
    app_state.prismUser.premium = true;
    CoinGateResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () async {
              result = await CoinGate.forContext(context).run(
                CoinGateSpec(
                  action: CoinSpendAction.premiumFilter,
                  tags: const CoinGateTags(spend: 's', ad: 'a', insufficient: 'i'),
                  upsellSource: 'u',
                  upgradeSource: 'g',
                  isMounted: () => context.mounted,
                  perform: () async => true,
                  choose: (_) async => CoinGateChoice.cancel,
                ),
              );
            },
            child: const Text('run'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(result, CoinGateResult.performedFree);
  });
}
