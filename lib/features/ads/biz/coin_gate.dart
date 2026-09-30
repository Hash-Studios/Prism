import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';
import 'package:Prism/features/ads/biz/coin_gate_port.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CoinGateResult {
  /// Coins were spent and the action succeeded.
  performed,

  /// Premium user: the action ran without a charge.
  performedFree,

  /// The user dismissed the prompt, chose to upgrade, or the ad was not credited.
  cancelled,

  /// The balance is too low and the user did not top up.
  insufficient,

  /// The spend call itself failed. Nothing was charged.
  spendFailed,

  /// The action failed after a charge and the coins were refunded.
  failedRefunded,

  /// The action failed and no refund happened (free action, or the refund did not confirm).
  failedNotRefunded,
}

/// What the user picked in the gate prompt.
enum CoinGateChoice {
  /// Spend coins now.
  spend,

  /// Watch an ad, then retry the spend.
  watchAd,

  /// Open the paywall.
  upgrade,

  /// Stop.
  cancel,

  /// Nudge only: carry on as if the nudge was not shown.
  proceed,
}

enum CoinGatePhase { nudge, insufficient }

class CoinGatePrompt {
  const CoinGatePrompt({required this.phase, required this.cost, required this.balance});

  final CoinGatePhase phase;
  final int cost;
  final int balance;

  bool get canSpend => balance >= cost;
}

/// The analytics `sourceTag` strings for each step. Keep them stable: dashboards read them.
class CoinGateTags {
  const CoinGateTags({
    required this.spend,
    required this.ad,
    required this.insufficient,
    this.nudge,
    this.nudgeSpend,
    this.retrySpend,
  });

  final String spend;
  final String ad;

  /// Logged when the pre-spend nudge shows. Defaults to [insufficient].
  final String? nudge;

  /// Logged when the spend is refused for low balance and the prompt shows.
  final String insufficient;

  /// Spend tag when the user taps "spend" in the nudge. Defaults to [spend].
  final String? nudgeSpend;

  /// Spend tag for the retry after a rewarded ad. Defaults to [spend].
  final String? retrySpend;
}

class CoinGateSpec {
  const CoinGateSpec({
    required this.action,
    required this.tags,
    required this.upsellSource,
    required this.upgradeSource,
    required this.perform,
    required this.choose,
    required this.isMounted,
    this.reason,
    this.spend,
    this.nudgeBelow,
    this.confirmFirst = false,
    this.toastWhenInsufficient = false,
    this.spendErrorMessage = 'Unable to process coins right now.',
    this.failureLabel = 'Download failed',
    this.refundReason = 'download_failed_refund',
    this.onAttempt,
    this.onWatchChosen,
    this.onSpent,
  });

  final CoinSpendAction action;
  final CoinGateTags tags;

  /// Source for the "3rd ad watched" paywall upsell.
  final String upsellSource;
  final String upgradeSource;

  /// The gated work. Return false (or throw) when it failed: the charge is refunded.
  final Future<bool> Function() perform;

  /// Shows the caller's sheet. The gate logs the nudge event before calling it.
  final Future<CoinGateChoice> Function(CoinGatePrompt prompt) choose;
  final bool Function() isMounted;
  final String? reason;

  /// Replaces the plain coin spend (for example the 24h preview unlock).
  final Future<CoinMutationResult> Function(String sourceTag)? spend;

  /// Show the nudge first when the balance is below this.
  final int? nudgeBelow;

  /// Show the nudge first even when the balance is fine.
  final bool confirmFirst;

  /// Toast "Need N more coins." before re-prompting after a refused spend.
  final bool toastWhenInsufficient;
  final String spendErrorMessage;
  final String failureLabel;
  final String refundReason;
  final void Function(String spendTag)? onAttempt;
  final VoidCallback? onWatchChosen;

  /// Called when coins really left the balance, before [perform].
  final void Function(String spendTag, CoinMutationResult result)? onSpent;
}

/// One place for the premium bypass, spend, low-balance sheet, rewarded ad, credit, retry, refund sequence.
class CoinGate {
  CoinGate(this._port);

  factory CoinGate.forContext(BuildContext context) => CoinGate(AppCoinGatePort(() => context.read<AdsBloc>()));

  final CoinGatePort _port;

  Future<CoinGateResult> run(CoinGateSpec spec) async {
    if (_port.isPremium) {
      return await _perform(spec, 'premium_bypass') ? CoinGateResult.performedFree : CoinGateResult.failedNotRefunded;
    }

    final int cost = spec.action.cost();
    CoinGatePrompt? prompt;
    final int? nudgeBelow = spec.nudgeBelow;
    final int balance = _port.balance;
    final bool low = nudgeBelow != null && balance < nudgeBelow;
    if (low || spec.confirmFirst) {
      prompt = CoinGatePrompt(phase: CoinGatePhase.nudge, cost: cost, balance: balance);
    }
    String spendTag = spec.tags.spend;

    while (true) {
      if (prompt != null) {
        if (!spec.isMounted()) {
          return CoinGateResult.cancelled;
        }
        final CoinGatePrompt current = prompt;
        prompt = null;
        if (current.phase == CoinGatePhase.insufficient || low) {
          _port.logLowBalanceNudge(
            sourceTag: current.phase == CoinGatePhase.nudge
                ? spec.tags.nudge ?? spec.tags.insufficient
                : spec.tags.insufficient,
            requiredCoins: cost,
          );
        }
        switch (await spec.choose(current)) {
          case CoinGateChoice.cancel:
            return CoinGateResult.cancelled;
          case CoinGateChoice.upgrade:
            if (spec.isMounted()) {
              await _port.presentLowBalancePaywall(source: spec.upgradeSource);
            }
            return CoinGateResult.cancelled;
          case CoinGateChoice.watchAd:
            return _watchAndRetry(spec, cost);
          case CoinGateChoice.spend:
            spendTag = current.phase == CoinGatePhase.nudge ? spec.tags.nudgeSpend ?? spec.tags.spend : spec.tags.spend;
          case CoinGateChoice.proceed:
            if (current.phase == CoinGatePhase.insufficient) {
              return CoinGateResult.cancelled;
            }
            if (!current.canSpend) {
              prompt = CoinGatePrompt(phase: CoinGatePhase.insufficient, cost: cost, balance: current.balance);
              continue;
            }
            spendTag = spec.tags.spend;
        }
      }

      final CoinGateResult result = await _spendAndPerform(spec, spendTag);
      if (result != CoinGateResult.insufficient) {
        return result;
      }
      if (spec.toastWhenInsufficient) {
        _port.showError('Need ${(cost - _port.balance).clamp(1, cost)} more coins.');
      }
      prompt = CoinGatePrompt(phase: CoinGatePhase.insufficient, cost: cost, balance: _port.balance);
    }
  }

  /// Earn-only path: watch a rewarded ad and credit the coins. Returns true when the coins landed.
  Future<bool> watchAdForCoins({
    required String sourceTag,
    required String upsellSource,
    required bool Function() isMounted,
  }) async {
    if (!await _port.watchRewardedAd()) {
      _port.showError('Ad was not completed.');
      return false;
    }
    try {
      final CoinMutationResult credit = await _port.award(CoinEarnAction.rewardedAd, sourceTag: sourceTag);
      if (!credit.changed) {
        _port.showError('Unable to credit coins right now.');
        return false;
      }
      if (isMounted()) {
        await _port.recordRewardedAdWatch(source: upsellSource);
      }
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: sourceTag, error: error, stackTrace: stackTrace);
      _port.showError('Unable to credit coins right now.');
      return false;
    }
    return true;
  }

  Future<CoinGateResult> _watchAndRetry(CoinGateSpec spec, int cost) async {
    spec.onWatchChosen?.call();
    final bool credited = await watchAdForCoins(
      sourceTag: spec.tags.ad,
      upsellSource: spec.upsellSource,
      isMounted: spec.isMounted,
    );
    if (!credited) {
      return CoinGateResult.cancelled;
    }
    final int balance = _port.balance;
    if (balance < cost) {
      _port.showError('Need ${cost - balance} more coins.');
      return CoinGateResult.insufficient;
    }
    return _spendAndPerform(spec, spec.tags.retrySpend ?? spec.tags.spend);
  }

  Future<CoinGateResult> _spendAndPerform(CoinGateSpec spec, String tag) async {
    spec.onAttempt?.call(tag);
    final CoinMutationResult spent;
    try {
      spent = await (spec.spend?.call(tag) ?? _port.spend(spec.action, sourceTag: tag, reason: spec.reason));
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: tag, error: error, stackTrace: stackTrace);
      _port.showError(spec.spendErrorMessage);
      return CoinGateResult.spendFailed;
    }
    if (!spent.success) {
      if (spent.insufficientBalance) {
        return CoinGateResult.insufficient;
      }
      _port.showError(spec.spendErrorMessage);
      return CoinGateResult.spendFailed;
    }
    if (spent.changed) {
      spec.onSpent?.call(tag, spent);
    }
    if (await _perform(spec, tag)) {
      return CoinGateResult.performed;
    }
    return spent.changed ? _refund(spec, tag, spent) : CoinGateResult.failedNotRefunded;
  }

  Future<bool> _perform(CoinGateSpec spec, String tag) async {
    try {
      return await spec.perform();
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: tag, error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<CoinGateResult> _refund(CoinGateSpec spec, String tag, CoinMutationResult spent) async {
    final String refundTag = '$tag.refund';
    try {
      final CoinMutationResult refund = await _port.refundSpend(
        spec.action,
        sourceTag: refundTag,
        transactionId: spent.transactionId,
        reason: spec.refundReason,
      );
      if (refund.success && refund.changed) {
        _port.showSuccess('${spec.failureLabel}. ${refund.delta} coins refunded.');
        return CoinGateResult.failedRefunded;
      }
      _port.logCoinError(sourceTag: refundTag, error: StateError('Coin refund was not applied: ${refund.reason}'));
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: refundTag, error: error, stackTrace: stackTrace);
    }
    _port.showError('${spec.failureLabel}. Your refund could not be confirmed.');
    return CoinGateResult.failedNotRefunded;
  }
}
