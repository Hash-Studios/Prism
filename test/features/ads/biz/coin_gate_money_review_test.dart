import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_coin_gate_port.dart';

const CoinGateTags _tags = CoinGateTags(spend: 'x.spend', ad: 'x.ad', insufficient: 'x.low');

void main() {
  test('unlock granted by the spend stays paid when the host unmounts during the spend', () async {
    final FakeCoinGatePort port = FakeCoinGatePort(balance: 10);
    bool mounted = true;
    bool entitlementGranted = false;
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumPreview24h,
        tags: _tags,
        upsellSource: 'u',
        upgradeSource: 'g',
        isMounted: () => mounted,
        choose: (_) async => CoinGateChoice.cancel,
        spend: (String tag) async {
          final CoinMutationResult result = await port.spend(CoinSpendAction.premiumPreview24h, sourceTag: tag);
          entitlementGranted = true;
          mounted = false;
          return result;
        },
        refundOnFailure: false,
        perform: () async => true,
      ),
    );
    expect(port.log.where((String e) => e.startsWith('refund')), isEmpty);
    expect(result, CoinGateResult.performed);
    expect(port.balance, 0);
    expect(entitlementGranted, isTrue);
  });

  test('already granted unlock is not refunded when navigation fails', () async {
    final FakeCoinGatePort port = FakeCoinGatePort(balance: 10);
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumPreview24h,
        tags: _tags,
        upsellSource: 'u',
        upgradeSource: 'g',
        isMounted: () => true,
        choose: (_) async => CoinGateChoice.cancel,
        spend: (String tag) => port.spend(CoinSpendAction.premiumPreview24h, sourceTag: tag),
        refundOnFailure: false,
        perform: () async => false,
      ),
    );

    expect(port.log.where((String e) => e.startsWith('refund')), isEmpty);
    expect(port.balance, 0);
    expect(result, CoinGateResult.failedNotRefunded);
  });

  test('unchanged successful spend is not refunded after failed perform', () async {
    final FakeCoinGatePort port = FakeCoinGatePort(balance: 10);
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumPreview24h,
        tags: _tags,
        upsellSource: 'u',
        upgradeSource: 'g',
        isMounted: () => true,
        choose: (_) async => CoinGateChoice.cancel,
        spend: (String tag) async => CoinMutationResult.noChange(balance: 10),
        perform: () async => false,
      ),
    );

    expect(port.log.where((String e) => e.startsWith('refund')), isEmpty);
    expect(port.balance, 10);
    expect(result, CoinGateResult.failedNotRefunded);
  });

  test('balance below the cost but above the nudge threshold opens the sheet without a spend call', () async {
    final FakeCoinGatePort port = FakeCoinGatePort(balance: 12);
    final List<CoinGatePrompt> prompts = <CoinGatePrompt>[];
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumWallpaperDownload,
        tags: _tags,
        upsellSource: 'u',
        upgradeSource: 'g',
        nudgeBelow: 10,
        precheckBalance: true,
        isMounted: () => true,
        perform: () async => true,
        choose: (CoinGatePrompt p) async {
          prompts.add(p);
          return CoinGateChoice.cancel;
        },
      ),
    );
    expect(result, CoinGateResult.cancelled);
    expect(prompts.single.phase, CoinGatePhase.insufficient);
    expect(port.log, <String>['nudge:x.low:15']);
  });
}
