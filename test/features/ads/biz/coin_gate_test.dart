import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_coin_gate_port.dart';

const CoinGateTags _tags = CoinGateTags(
  spend: 'x.spend',
  ad: 'x.ad',
  insufficient: 'x.low',
  retrySpend: 'x.retry.spend',
);

void main() {
  late FakeCoinGatePort port;
  late int performed;
  late bool performResult;
  late CoinGateChoice choice;
  late List<CoinGatePrompt> prompts;

  setUp(() {
    port = FakeCoinGatePort(balance: 10);
    performed = 0;
    performResult = true;
    choice = CoinGateChoice.cancel;
    prompts = <CoinGatePrompt>[];
  });

  CoinGateSpec spec({int? nudgeBelow, bool confirmFirst = false, bool mounted = true}) => CoinGateSpec(
    action: CoinSpendAction.premiumFilter,
    tags: _tags,
    upsellSource: 'upsell',
    upgradeSource: 'upgrade',
    nudgeBelow: nudgeBelow,
    confirmFirst: confirmFirst,
    isMounted: () => mounted,
    perform: () async {
      performed++;
      return performResult;
    },
    choose: (prompt) async {
      prompts.add(prompt);
      return choice;
    },
  );

  test('premium user skips the spend and runs the action', () async {
    port.isPremium = true;
    expect(await CoinGate(port).run(spec()), CoinGateResult.performedFree);
    expect(performed, 1);
    expect(port.log, isEmpty);
  });

  test('enough coins: spends then performs', () async {
    expect(await CoinGate(port).run(spec()), CoinGateResult.performed);
    expect(performed, 1);
    expect(port.balance, 5);
    expect(port.log, <String>['spend:x.spend']);
  });

  test('failed action refunds the charge', () async {
    performResult = false;
    expect(await CoinGate(port).run(spec()), CoinGateResult.failedRefunded);
    expect(port.balance, 10);
    expect(port.log.last, startsWith('refund:x.spend.refund:tx-x.spend:'));
    expect(port.successes.single, contains('coins refunded'));
  });

  test('refund that does not confirm is reported and not counted as refunded', () async {
    performResult = false;
    port.refundApplies = false;
    expect(await CoinGate(port).run(spec()), CoinGateResult.failedNotRefunded);
    expect(port.errors.single, contains('refund could not be confirmed'));
  });

  test('throwing action counts as a failure and refunds', () async {
    final CoinGateSpec base = spec();
    final CoinGateSpec throwing = CoinGateSpec(
      action: base.action,
      tags: base.tags,
      upsellSource: 'u',
      upgradeSource: 'g',
      isMounted: () => true,
      perform: () async => throw StateError('boom'),
      choose: base.choose,
    );
    expect(await CoinGate(port).run(throwing), CoinGateResult.failedRefunded);
    expect(port.balance, 10);
  });

  test('spend that throws shows the error and never runs the action', () async {
    port.spendThrows = true;
    expect(await CoinGate(port).run(spec()), CoinGateResult.spendFailed);
    expect(performed, 0);
    expect(port.errors, <String>['Unable to process coins right now.']);
  });

  test('low balance and cancel stops without a charge', () async {
    port.balance = 1;
    expect(await CoinGate(port).run(spec()), CoinGateResult.cancelled);
    expect(prompts.single.phase, CoinGatePhase.insufficient);
    expect(port.log, <String>['spend:x.spend', 'nudge:x.low:5']);
    expect(performed, 0);
  });

  test('low balance and upgrade opens the paywall', () async {
    port.balance = 1;
    choice = CoinGateChoice.upgrade;
    expect(await CoinGate(port).run(spec()), CoinGateResult.cancelled);
    expect(port.log.last, 'paywall:upgrade');
  });

  test('watch ad credits coins, retries the spend with the retry tag, then performs', () async {
    port.balance = 1;
    choice = CoinGateChoice.watchAd;
    expect(await CoinGate(port).run(spec()), CoinGateResult.performed);
    expect(port.log, <String>[
      'spend:x.spend',
      'nudge:x.low:5',
      'ad',
      'award:x.ad',
      'watch:upsell',
      'spend:x.retry.spend',
    ]);
    expect(performed, 1);
  });

  test('watch ad that is not completed cancels with the ad toast', () async {
    port.balance = 1;
    choice = CoinGateChoice.watchAd;
    port.adCompletes = false;
    expect(await CoinGate(port).run(spec()), CoinGateResult.cancelled);
    expect(port.errors, <String>['Ad was not completed.']);
    expect(performed, 0);
  });

  test('watch ad whose credit does not land cancels', () async {
    port.balance = 1;
    choice = CoinGateChoice.watchAd;
    port.awardChanges = false;
    expect(await CoinGate(port).run(spec()), CoinGateResult.cancelled);
    expect(port.errors, <String>['Unable to credit coins right now.']);
  });

  test('ad reward that is still short reports the missing coins', () async {
    port.balance = 0;
    port.awardAmount = 2;
    choice = CoinGateChoice.watchAd;
    expect(await CoinGate(port).run(spec()), CoinGateResult.insufficient);
    expect(port.errors.last, 'Need 3 more coins.');
    expect(performed, 0);
  });

  test('nudge below threshold lets the user proceed when they can afford it', () async {
    port.balance = 7;
    choice = CoinGateChoice.proceed;
    expect(await CoinGate(port).run(spec(nudgeBelow: 8)), CoinGateResult.performed);
    expect(prompts.single.phase, CoinGatePhase.nudge);
    expect(port.log.first, 'nudge:x.low:5');
  });

  test('confirmFirst cancel never spends', () async {
    expect(await CoinGate(port).run(spec(confirmFirst: true)), CoinGateResult.cancelled);
    expect(port.log, isEmpty);
  });

  test('unmounted host stops before showing a prompt', () async {
    port.balance = 1;
    expect(await CoinGate(port).run(spec(mounted: false)), CoinGateResult.cancelled);
    expect(prompts, isEmpty);
  });

  group('watchAdForCoins', () {
    bool mounted() => true;

    test('credits coins and records the watch', () async {
      expect(await CoinGate(port).watchAdForCoins(sourceTag: 's', upsellSource: 'u', isMounted: mounted), isTrue);
      expect(port.balance, 20);
      expect(port.log, <String>['ad', 'award:s', 'watch:u']);
    });

    test('incomplete ad shows the ad toast', () async {
      port.adCompletes = false;
      expect(await CoinGate(port).watchAdForCoins(sourceTag: 's', upsellSource: 'u', isMounted: mounted), isFalse);
      expect(port.errors, <String>['Ad was not completed.']);
    });

    test('award that throws is logged and shows the credit toast', () async {
      port.awardThrows = true;
      expect(await CoinGate(port).watchAdForCoins(sourceTag: 's', upsellSource: 'u', isMounted: mounted), isFalse);
      expect(port.errors, <String>['Unable to credit coins right now.']);
      expect(port.log, contains('error:s'));
    });
  });

  group('premium filter export (was: charge kept on a failed export)', () {
    test('failed export refunds and the filter is not counted as performed', () async {
      performResult = false;
      final CoinGateResult result = await CoinGate(port).run(
        CoinGateSpec(
          action: CoinSpendAction.premiumFilter,
          reason: 'filter_Noir',
          tags: _tags,
          upsellSource: 'premium_filter_watch_ad',
          upgradeSource: 'premium_filter_low_balance',
          isMounted: () => true,
          perform: () async => false,
          choose: (_) async => CoinGateChoice.cancel,
          failureLabel: 'Export failed',
          refundReason: 'premium_filter_export_failed_refund',
        ),
      );
      expect(result, CoinGateResult.failedRefunded);
      expect(port.balance, 10);
      expect(port.successes.single, 'Export failed. 5 coins refunded.');
      expect(port.log.last, contains('premium_filter_export_failed_refund'));
    });
  });
}
