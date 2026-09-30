import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_coin_gate_port.dart';

class _ThrowingUpsellPort extends FakeCoinGatePort {
  @override
  Future<void> recordRewardedAdWatch({required String source}) {
    log.add('watch:$source');
    return Future<void>.error(StateError('upsell failed'));
  }
}

void main() {
  bool mounted() => true;

  test('award exception keeps the rewards ad-failure toast and credits only once', () async {
    final FakeCoinGatePort port = FakeCoinGatePort()..awardThrows = true;

    expect(
      await CoinGate(port).watchAdForCoins(
        sourceTag: 'coins.hub.rewarded_ad',
        upsellSource: 'coin_hub_rewarded_ad',
        isMounted: mounted,
        adErrorMessage: 'Ad was not completed.',
      ),
      isFalse,
    );

    expect(port.log, <String>['ad', 'award:coins.hub.rewarded_ad', 'error:coins.hub.rewarded_ad']);
    expect(port.errors, <String>['Ad was not completed.']);
  });

  test('an unchanged award keeps the credit-failure toast', () async {
    final FakeCoinGatePort port = FakeCoinGatePort()..awardChanges = false;

    expect(
      await CoinGate(port).watchAdForCoins(
        sourceTag: 'coins.hub.rewarded_ad',
        upsellSource: 'coin_hub_rewarded_ad',
        isMounted: mounted,
        adErrorMessage: 'Ad was not completed.',
      ),
      isFalse,
    );

    expect(port.errors, <String>['Unable to credit coins right now.']);
  });

  test('upsell exception reports the rewards ad-failure toast after one successful credit', () async {
    final _ThrowingUpsellPort port = _ThrowingUpsellPort();

    expect(
      await CoinGate(port).watchAdForCoins(
        sourceTag: 'coins.hub.rewarded_ad',
        upsellSource: 'coin_hub_rewarded_ad',
        isMounted: mounted,
        adErrorMessage: 'Ad was not completed.',
      ),
      isFalse,
    );

    expect(port.log.where((entry) => entry == 'award:coins.hub.rewarded_ad'), hasLength(1));
    expect(port.errors, <String>['Ad was not completed.']);
  });
}
