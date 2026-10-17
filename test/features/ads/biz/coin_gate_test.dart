import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
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

  CoinGateSpec spec({
    int? nudgeBelow,
    bool confirmFirst = false,
    bool mounted = true,
    bool premiumBypass = true,
    CoinSpendAction action = CoinSpendAction.premiumFilter,
  }) => CoinGateSpec(
    action: action,
    premiumBypass: premiumBypass,
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

  test('premium user pays when the spec turns the bypass off', () async {
    port.isPremium = true;
    expect(await CoinGate(port).run(spec(premiumBypass: false)), CoinGateResult.performed);
    expect(port.log, <String>['spend:x.spend']);
  });

  test('premium user pays for actions outside the config bypass set', () async {
    port.isPremium = true;
    expect(await CoinGate(port).run(spec(action: CoinSpendAction.boostWall)), isNot(CoinGateResult.performedFree));
    expect(port.log.first, 'spend:x.spend');
    expect(performed, 0);
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

  test('throwing spent callback cannot strand a confirmed charge', () async {
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumFilter,
        tags: _tags,
        upsellSource: 'upsell',
        upgradeSource: 'upgrade',
        isMounted: () => true,
        perform: () async => false,
        choose: (_) async => CoinGateChoice.cancel,
        onSpent: (_, _) => throw StateError('success callback failed'),
      ),
    );

    expect(result, CoinGateResult.failedRefunded);
    expect(port.balance, 10);
    expect(port.log, contains('error:x.spend'));
  });

  test('premium activated while prompt is open performs without spending', () async {
    port.balance = 1;
    final CoinGateSpec pendingPrompt = CoinGateSpec(
      action: CoinSpendAction.premiumFilter,
      tags: _tags,
      upsellSource: 'upsell',
      upgradeSource: 'upgrade',
      isMounted: () => true,
      perform: () async {
        performed++;
        return true;
      },
      choose: (_) async {
        port.isPremium = true;
        return CoinGateChoice.spend;
      },
      confirmFirst: true,
    );

    expect(await CoinGate(port).run(pendingPrompt), CoinGateResult.performedFree);
    expect(port.log, isEmpty);
    expect(performed, 1);
  });

  test('premium activated while prompt is open does not override cancel', () async {
    port.balance = 1;
    final CoinGateSpec pendingPrompt = CoinGateSpec(
      action: CoinSpendAction.premiumFilter,
      tags: _tags,
      upsellSource: 'upsell',
      upgradeSource: 'upgrade',
      isMounted: () => true,
      perform: () async {
        performed++;
        return true;
      },
      choose: (_) async {
        port.isPremium = true;
        return CoinGateChoice.cancel;
      },
      confirmFirst: true,
    );

    expect(await CoinGate(port).run(pendingPrompt), CoinGateResult.cancelled);
    expect(performed, 0);
    expect(port.log, isEmpty);
  });

  test('unmounted after a confirmed spend refunds without performing', () async {
    bool mounted = true;
    port.afterSpend = () async => mounted = false;
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumFilter,
        tags: _tags,
        upsellSource: 'upsell',
        upgradeSource: 'upgrade',
        isMounted: () => mounted,
        perform: () async {
          performed++;
          return true;
        },
        choose: (_) async => CoinGateChoice.cancel,
      ),
    );

    expect(result, CoinGateResult.failedRefunded);
    expect(port.balance, 10);
    expect(performed, 0);
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

  test('premium reached during ad upsell still runs the custom unlock attempt', () async {
    port.balance = 1;
    port.afterRecord = () async => port.isPremium = true;
    int attempts = 0;
    int customSpends = 0;
    final CoinGateSpec retry = CoinGateSpec(
      action: CoinSpendAction.premiumPreview24h,
      tags: _tags,
      upsellSource: 'upsell',
      upgradeSource: 'upgrade',
      isMounted: () => true,
      spend: (_) async {
        customSpends++;
        return CoinMutationResult.noChange(balance: port.balance);
      },
      onAttempt: (_) => attempts++,
      perform: () async => true,
      choose: (_) async => CoinGateChoice.cancel,
    );
    final CoinGateSpec initial = CoinGateSpec(
      action: retry.action,
      tags: retry.tags,
      upsellSource: retry.upsellSource,
      upgradeSource: retry.upgradeSource,
      isMounted: retry.isMounted,
      spend: retry.spend,
      onAttempt: retry.onAttempt,
      perform: retry.perform,
      choose: (_) async => CoinGateChoice.watchAd,
      confirmFirst: true,
      retrySpec: () => retry,
    );

    expect(await CoinGate(port).run(initial), CoinGateResult.performed);
    expect(attempts, 1);
    expect(customSpends, 1);
    expect(port.balance, 11);
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

  test('ad reward that is still short returns to the low-balance prompt with the coins still missing', () async {
    port.balance = 0;
    port.awardAmount = 2;
    final List<CoinGateChoice> choices = <CoinGateChoice>[CoinGateChoice.watchAd, CoinGateChoice.cancel];
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumFilter,
        tags: _tags,
        upsellSource: 'upsell',
        upgradeSource: 'upgrade',
        isMounted: () => true,
        perform: () async {
          performed++;
          return performResult;
        },
        choose: (prompt) async {
          prompts.add(prompt);
          return choices.removeAt(0);
        },
        precheckBalance: true,
      ),
    );
    expect(result, CoinGateResult.cancelled);
    expect(prompts.map((p) => p.phase), <CoinGatePhase>[CoinGatePhase.insufficient, CoinGatePhase.insufficient]);
    expect(prompts.map((p) => p.missing), <int>[5, 3]);
    expect(port.errors, isEmpty);
    expect(performed, 0);
  });

  test('several ads can cover a Pro wallpaper that costs more than one ad pays', () async {
    port.balance = 0;
    final List<CoinGateChoice> choices = <CoinGateChoice>[
      CoinGateChoice.watchAd,
      CoinGateChoice.watchAd,
      CoinGateChoice.watchAd,
    ];
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumWallpaperDownload,
        tags: _tags,
        upsellSource: 'upsell',
        upgradeSource: 'upgrade',
        isMounted: () => true,
        perform: () async {
          performed++;
          return true;
        },
        choose: (prompt) async {
          prompts.add(prompt);
          return choices.removeAt(0);
        },
        precheckBalance: true,
      ),
    );
    expect(result, CoinGateResult.performed);
    expect(prompts.map((p) => p.missing), <int>[25, 15, 5]);
    expect(port.log.where((e) => e == 'ad'), hasLength(3));
    expect(performed, 1);
    expect(port.balance, 5);
  });

  test('the prompt carries the ad consent and the ads left today', () async {
    port.balance = 1;
    port.consentGiven = false;
    port.adsRemaining = 0;
    await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumFilter,
        tags: _tags,
        upsellSource: 'upsell',
        upgradeSource: 'upgrade',
        isMounted: () => true,
        perform: () async => true,
        choose: (prompt) async {
          prompts.add(prompt);
          return CoinGateChoice.cancel;
        },
        precheckBalance: true,
      ),
    );
    expect(prompts.single.adsAllowed, isFalse);
    expect(prompts.single.adsRemaining, 0);
    expect(prompts.single.canWatchAd, isFalse);
  });

  test('a prompt with consent and ads left allows an ad', () async {
    port.balance = 1;
    port.adsRemaining = 3;
    await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumFilter,
        tags: _tags,
        upsellSource: 'upsell',
        upgradeSource: 'upgrade',
        isMounted: () => true,
        perform: () async => true,
        choose: (prompt) async {
          prompts.add(prompt);
          return CoinGateChoice.cancel;
        },
        precheckBalance: true,
      ),
    );
    expect(prompts.single.canWatchAd, isTrue);
    expect(prompts.single.adsRemaining, 3);
  });

  group('ad failure copy', () {
    const Map<AdFailureReason?, String> copy = <AdFailureReason?, String>{
      AdFailureReason.consent: 'Ads are off. Change this in Settings > Privacy.',
      AdFailureReason.noFill: 'No ad is available right now. Try again later.',
      AdFailureReason.offline: 'You are offline. Check your connection and try again.',
      AdFailureReason.timeout: 'Ad was not completed.',
      AdFailureReason.other: 'Ad was not completed.',
      null: 'Ad was not completed.',
    };
    for (final MapEntry<AdFailureReason?, String> entry in copy.entries) {
      test('${entry.key} shows "${entry.value}"', () async {
        port.balance = 1;
        choice = CoinGateChoice.watchAd;
        port.adCompletes = false;
        port.adFailure = entry.key;
        expect(await CoinGate(port).run(spec()), CoinGateResult.cancelled);
        expect(port.errors, <String>[entry.value]);
      });
    }
  });

  test('a daily-limit reply shows the limit copy', () async {
    port.balance = 1;
    choice = CoinGateChoice.watchAd;
    port.awardChanges = false;
    port.awardReason = 'rewarded_ad_limit';
    expect(await CoinGate(port).run(spec()), CoinGateResult.cancelled);
    expect(port.errors, <String>['Daily limit reached. Back tomorrow.']);
  });

  test('a reward the server may have granted is reported as pending, not as an error', () async {
    port.balance = 1;
    choice = CoinGateChoice.watchAd;
    port.awardChanges = false;
    port.awardUnknownOutcome = 'award_u_r';
    expect(await CoinGate(port).run(spec()), CoinGateResult.cancelled);
    expect(port.errors, isEmpty);
    expect(port.infos, <String>[rewardPendingMessage]);
  });

  test('the spend carries the ledger label and the download marker link', () async {
    await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumFilter,
        tags: _tags,
        upsellSource: 'upsell',
        upgradeSource: 'upgrade',
        label: 'Wallpaper by Ana',
        pendingDownloadLink: 'https://x.test/a.jpg',
        isMounted: () => true,
        perform: () async => true,
        choose: (_) async => CoinGateChoice.cancel,
      ),
    );
    expect(port.spendLabels, <String>['Wallpaper by Ana']);
    expect(port.pendingDownloadLinks, <String?>['https://x.test/a.jpg']);
  });

  test('initial precheck skips spend when balance is short', () async {
    port.balance = 1;
    expect(
      await CoinGate(port).run(
        CoinGateSpec(
          action: CoinSpendAction.premiumFilter,
          tags: _tags,
          upsellSource: 'upsell',
          upgradeSource: 'upgrade',
          isMounted: () => true,
          perform: () async => true,
          choose: (prompt) async {
            prompts.add(prompt);
            return CoinGateChoice.cancel;
          },
          precheckBalance: true,
        ),
      ),
      CoinGateResult.cancelled,
    );
    expect(port.log, <String>['nudge:x.low:5']);
    expect(prompts.single.phase, CoinGatePhase.insufficient);
  });

  test('retry spec reopens insufficient prompt after attempting spend', () async {
    port.balance = 1;
    port.awardAmount = 2;
    choice = CoinGateChoice.watchAd;
    int prompted = 0;
    Future<CoinGateChoice> choose(CoinGatePrompt _) async {
      prompted++;
      return prompted == 1 ? CoinGateChoice.watchAd : CoinGateChoice.cancel;
    }

    final CoinGateSpec retry = CoinGateSpec(
      action: CoinSpendAction.premiumFilter,
      tags: _tags,
      upsellSource: 'upsell',
      upgradeSource: 'upgrade',
      isMounted: () => true,
      perform: () async => true,
      choose: choose,
    );
    final CoinGateSpec initial = CoinGateSpec(
      action: retry.action,
      tags: retry.tags,
      upsellSource: retry.upsellSource,
      upgradeSource: retry.upgradeSource,
      isMounted: retry.isMounted,
      perform: retry.perform,
      choose: retry.choose,
      confirmFirst: true,
      retrySpec: () => retry,
    );

    expect(await CoinGate(port).run(initial), CoinGateResult.cancelled);
    expect(port.log, <String>['ad', 'award:x.ad', 'watch:upsell', 'spend:x.spend', 'nudge:x.low:5']);
    expect(prompted, 2);
  });

  test('nudge spend refusal can stop without reopening the prompt', () async {
    port.spendAlwaysInsufficient = true;
    choice = CoinGateChoice.spend;
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumFilter,
        tags: _tags,
        upsellSource: 'upsell',
        upgradeSource: 'upgrade',
        isMounted: () => true,
        perform: () async => true,
        choose: (prompt) async {
          prompts.add(prompt);
          return choice;
        },
        nudgeBelow: 11,
        confirmFirst: true,
        repromptOnNudgeSpendInsufficient: false,
      ),
    );

    expect(result, CoinGateResult.insufficient);
    expect(prompts, hasLength(1));
    expect(port.log, <String>['nudge:x.low:5', 'spend:x.spend']);
  });

  test('stale insufficient result omits nudge analytics when balance now covers cost', () async {
    port.spendAlwaysInsufficient = true;
    final CoinGateResult result = await CoinGate(port).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumFilter,
        tags: _tags,
        upsellSource: 'upsell',
        upgradeSource: 'upgrade',
        isMounted: () => true,
        perform: () async => true,
        choose: (_) async => CoinGateChoice.cancel,
        logInsufficientOnlyWhenLow: true,
      ),
    );

    expect(result, CoinGateResult.cancelled);
    expect(port.log, <String>['spend:x.spend']);
  });

  test('prompt spend tag stays distinct from automatic ad retry tag', () async {
    port.balance = 1;
    port.awardAmount = 2;
    port.spendAlwaysInsufficient = true;
    int prompted = 0;
    final CoinGateSpec retry = CoinGateSpec(
      action: CoinSpendAction.premiumFilter,
      tags: const CoinGateTags(
        spend: 'x.auto.retry',
        promptSpend: 'x.manual',
        retrySpend: 'x.auto.retry',
        ad: 'x.ad',
        insufficient: 'x.low',
      ),
      upsellSource: 'upsell',
      upgradeSource: 'upgrade',
      isMounted: () => true,
      perform: () async => true,
      choose: (_) async {
        prompted++;
        return prompted == 1 ? CoinGateChoice.spend : CoinGateChoice.cancel;
      },
    );
    final CoinGateSpec initial = CoinGateSpec(
      action: retry.action,
      tags: retry.tags,
      upsellSource: retry.upsellSource,
      upgradeSource: retry.upgradeSource,
      isMounted: retry.isMounted,
      perform: retry.perform,
      choose: (_) async => CoinGateChoice.watchAd,
      confirmFirst: true,
      retrySpec: () => retry,
    );

    expect(await CoinGate(port).run(initial), CoinGateResult.cancelled);
    expect(port.log, <String>[
      'ad',
      'award:x.ad',
      'watch:upsell',
      'spend:x.auto.retry',
      'nudge:x.low:5',
      'spend:x.manual',
      'nudge:x.low:5',
    ]);
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

  test('host disposed while prompt is open does not spend', () async {
    port.balance = 1;
    bool mounted = true;
    final CoinGateSpec pendingPrompt = CoinGateSpec(
      action: CoinSpendAction.premiumFilter,
      tags: _tags,
      upsellSource: 'upsell',
      upgradeSource: 'upgrade',
      isMounted: () => mounted,
      perform: () async {
        performed++;
        return true;
      },
      choose: (_) async {
        mounted = false;
        return CoinGateChoice.spend;
      },
      confirmFirst: true,
    );

    expect(await CoinGate(port).run(pendingPrompt), CoinGateResult.cancelled);
    expect(port.log, isEmpty);
    expect(performed, 0);
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

    test('ad provider exception is logged and reported as incomplete', () async {
      port.adThrows = true;
      expect(await CoinGate(port).watchAdForCoins(sourceTag: 's', upsellSource: 'u', isMounted: mounted), isFalse);
      expect(port.errors, <String>['Ad was not completed.']);
      expect(port.log, <String>['ad', 'error:s']);
    });

    test('upsell recording failure reports failure without awarding a second time', () async {
      port.recordThrows = true;
      expect(await CoinGate(port).watchAdForCoins(sourceTag: 's', upsellSource: 'u', isMounted: mounted), isFalse);
      expect(port.balance, 20);
      expect(port.log, <String>['ad', 'award:s', 'watch:u', 'error:s']);
      expect(port.errors, <String>['Unable to credit coins right now.']);
    });

    test('filter-style ad flow does not credit after unmount', () async {
      bool mountedNow = true;
      port.afterAd = () async => mountedNow = false;
      expect(
        await CoinGate(
          port,
        ).watchAdForCoins(sourceTag: 's', upsellSource: 'u', isMounted: () => mountedNow, creditAfterUnmount: false),
        isFalse,
      );
      expect(port.balance, 10);
      expect(port.log, <String>['ad']);
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

  group('paid download ledger', () {
    const String link = 'https://x.test/a.jpg';
    const String txId = 'ledger-x.spend';
    const String refundCall = 'refund:x.spend.refund:tx-x.spend:download_failed_refund';

    CoinGateSpec downloadSpec({
      Future<bool> Function()? perform,
      bool Function()? isMounted,
      bool refundOnFailure = true,
      void Function(String txId)? onPaid,
      String? pendingDownloadLink = link,
    }) => CoinGateSpec(
      action: CoinSpendAction.premiumFilter,
      tags: _tags,
      upsellSource: 'upsell',
      upgradeSource: 'upgrade',
      pendingDownloadLink: pendingDownloadLink,
      refundOnFailure: refundOnFailure,
      onPaid: onPaid,
      isMounted: isMounted ?? () => true,
      perform: perform ?? () async => true,
      choose: (_) async => CoinGateChoice.cancel,
    );

    test('a finished action clears the entry', () async {
      expect(await CoinGate(port).run(downloadSpec()), CoinGateResult.performed);
      expect(port.log, <String>['spend:x.spend', 'clear:$txId']);
    });

    test('a failed action with a confirmed refund clears the entry', () async {
      expect(await CoinGate(port).run(downloadSpec(perform: () async => false)), CoinGateResult.failedRefunded);
      expect(port.log, <String>['spend:x.spend', refundCall, 'clear:$txId']);
    });

    test('a failed action with a refund that does not confirm releases the entry', () async {
      port.refundApplies = false;
      expect(await CoinGate(port).run(downloadSpec(perform: () async => false)), CoinGateResult.failedNotRefunded);
      expect(port.log, <String>['spend:x.spend', refundCall, 'error:x.spend.refund', 'release:$txId']);
    });

    test('a refund that throws releases the entry', () async {
      final _ThrowingRefundPort throwing = _ThrowingRefundPort(balance: 10);
      expect(await CoinGate(throwing).run(downloadSpec(perform: () async => false)), CoinGateResult.failedNotRefunded);
      expect(throwing.log, <String>['spend:x.spend', 'refund-threw', 'error:x.spend.refund', 'release:$txId']);
    });

    test('a failed action that is not refunded by design releases the entry', () async {
      expect(
        await CoinGate(port).run(downloadSpec(perform: () async => false, refundOnFailure: false)),
        CoinGateResult.failedNotRefunded,
      );
      expect(port.log, <String>['spend:x.spend', 'release:$txId']);
    });

    test('leaving the screen during the spend still tells the caller and clears a confirmed refund', () async {
      bool mounted = true;
      port.afterSpend = () async => mounted = false;
      final List<String> paid = <String>[];

      final CoinGateResult result = await CoinGate(
        port,
      ).run(downloadSpec(isMounted: () => mounted, onPaid: paid.add, perform: () async => fail('must not perform')));

      expect(result, CoinGateResult.failedRefunded);
      expect(paid, <String>[txId]);
      expect(port.log, <String>['spend:x.spend', refundCall, 'clear:$txId']);
    });

    test('leaving the screen during the spend releases the entry when the refund does not confirm', () async {
      bool mounted = true;
      port.refundApplies = false;
      port.afterSpend = () async => mounted = false;

      final CoinGateResult result = await CoinGate(port).run(downloadSpec(isMounted: () => mounted));

      expect(result, CoinGateResult.failedNotRefunded);
      expect(port.log, <String>['spend:x.spend', refundCall, 'error:x.spend.refund', 'release:$txId']);
    });

    test('leaving the screen during a spend that is not refunded by design releases the entry', () async {
      bool mounted = true;
      port.afterSpend = () async => mounted = false;

      final CoinGateResult result = await CoinGate(
        port,
      ).run(downloadSpec(isMounted: () => mounted, refundOnFailure: false));

      expect(result, CoinGateResult.performed);
      expect(port.log, <String>['spend:x.spend', 'release:$txId']);
    });

    test('the caller learns the id before the action runs', () async {
      final List<String> order = <String>[];

      await CoinGate(port).run(
        downloadSpec(
          onPaid: (String id) => order.add('paid:$id'),
          perform: () async {
            order.add('perform');
            return true;
          },
        ),
      );

      expect(order, <String>['paid:$txId', 'perform']);
    });

    test('a throwing paid callback cannot strand the charge', () async {
      expect(
        await CoinGate(port).run(downloadSpec(onPaid: (_) => throw StateError('callback failed'))),
        CoinGateResult.performed,
      );
      expect(port.log, <String>['spend:x.spend', 'error:x.spend', 'clear:$txId']);
    });

    test('a ledger call that throws never changes the result', () async {
      port.ledgerThrows = true;
      expect(await CoinGate(port).run(downloadSpec()), CoinGateResult.performed);
      expect(port.log, <String>['spend:x.spend', 'clear:$txId', 'error:x.spend.ledger_clear']);
    });

    test('a spend that is not a tracked download never touches the ledger', () async {
      expect(await CoinGate(port).run(downloadSpec(pendingDownloadLink: null)), CoinGateResult.performed);
      expect(
        await CoinGate(port).run(downloadSpec(pendingDownloadLink: null, perform: () async => false)),
        CoinGateResult.failedRefunded,
      );
      expect(port.log.where((String entry) => entry.startsWith('clear:') || entry.startsWith('release:')), isEmpty);
    });

    test('a premium run has no charge to settle and never calls the paid callback', () async {
      port.isPremium = true;
      final List<String> paid = <String>[];

      expect(await CoinGate(port).run(downloadSpec(onPaid: paid.add)), CoinGateResult.performedFree);

      expect(paid, isEmpty);
      expect(port.log, isEmpty);
    });

    test('a refused spend settles nothing', () async {
      port.balance = 1;
      final List<String> paid = <String>[];

      expect(await CoinGate(port).run(downloadSpec(onPaid: paid.add)), CoinGateResult.cancelled);

      expect(paid, isEmpty);
      expect(port.log.where((String entry) => entry.startsWith('clear:') || entry.startsWith('release:')), isEmpty);
    });
  });
}

class _ThrowingRefundPort extends FakeCoinGatePort {
  _ThrowingRefundPort({super.balance});

  @override
  Future<CoinMutationResult> refundSpend(
    CoinSpendAction action, {
    required String sourceTag,
    required String transactionId,
    required String reason,
  }) {
    log.add('refund-threw');
    return Future<CoinMutationResult>.error(StateError('refund failed'));
  }
}
