import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';
import 'package:Prism/features/ads/biz/coin_gate_port.dart';
import 'package:Prism/features/ads/biz/rewarded_ad_flow.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
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

  /// The spend call failed. The caller did not receive a confirmed charge.
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
  const CoinGatePrompt({
    required this.phase,
    required this.cost,
    required this.balance,
    this.adsAllowed = true,
    this.adsRemaining,
  });

  final CoinGatePhase phase;
  final int cost;
  final int balance;

  /// False when the user refused ad consent. The prompt must not offer an ad.
  final bool adsAllowed;

  /// Rewarded ads left today, when known.
  final int? adsRemaining;

  /// Coins the user still lacks. Zero when the balance covers the cost.
  int get missing => (cost - balance).clamp(0, cost);

  /// Whether the prompt may offer a rewarded ad: consent is given and the daily limit is not reached.
  bool get canWatchAd => adsAllowed && (adsRemaining ?? 1) > 0;

  bool get canSpend => balance >= cost;
}

/// The analytics `sourceTag` strings for each step. Keep them stable: dashboards read them.
class CoinGateTags {
  const CoinGateTags({
    required this.spend,
    required this.ad,
    required this.insufficient,
    this.nudge,
    this.promptSpend,
    this.nudgeSpend,
    this.retrySpend,
  });

  final String spend;
  final String ad;

  /// Logged when the pre-spend nudge shows. Defaults to [insufficient].
  final String? nudge;

  /// Spend tag when the user explicitly picks spend in a prompt.
  final String? promptSpend;

  /// Logged when the spend is refused for low balance and the prompt shows.
  final String insufficient;

  /// Spend tag when the user explicitly chooses to spend. Defaults to the phase-specific tag.
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
    this.label,
    this.pendingDownloadLink,
    this.spend,
    this.nudgeBelow,
    this.confirmFirst = false,
    this.toastWhenInsufficient = false,
    this.logInsufficientOnlyWhenLow = false,
    this.precheckBalance = false,
    this.repromptOnNudgeSpendInsufficient = true,
    this.creditAfterUnmount = true,
    this.refundOnFailure = true,
    this.adErrorMessage,
    this.spendErrorMessage,
    this.failureLabel,
    this.refundReason = 'download_failed_refund',
    this.onAttempt,
    this.onWatchChosen,
    this.onPaid,
    this.onSpent,
    this.retrySpec,
    this.premiumBypass = true,
  });

  final CoinSpendAction action;
  final CoinGateTags tags;

  /// Source for the "3rd ad watched" paywall upsell.
  final String upsellSource;
  final String upgradeSource;

  /// The gated work. Return false (or throw) when it failed; the gate attempts a refund for a confirmed charge if enabled.
  final Future<bool> Function() perform;

  /// Shows the caller's sheet. The gate logs the nudge event before calling it.
  final Future<CoinGateChoice> Function(CoinGatePrompt prompt) choose;
  final bool Function() isMounted;
  final String? reason;

  /// Text for the coin history row of this spend.
  final String? label;

  /// Marks the spend as a download of this link, so a download that never finishes is refunded.
  final String? pendingDownloadLink;

  /// Replaces the plain coin spend (for example the 24h preview unlock).
  final Future<CoinMutationResult> Function(String sourceTag)? spend;

  /// Show the nudge first when the balance is below this.
  final int? nudgeBelow;

  /// Show the nudge first even when the balance is fine.
  final bool confirmFirst;

  /// Toast "Need N more coins." before re-prompting after a refused spend.
  final bool toastWhenInsufficient;

  /// Preserve callers that log an insufficient prompt only while the local balance is below cost.
  final bool logInsufficientOnlyWhenLow;

  /// Open the insufficient prompt instead of attempting an initial spend when the visible balance is short.
  final bool precheckBalance;

  /// Reopen the low-balance prompt if a nudge's spend choice is refused.
  final bool repromptOnNudgeSpendInsufficient;

  /// Keep rewarded-ad crediting after dismissal except for flows that historically stopped on unmount.
  final bool creditAfterUnmount;

  /// Disable refunds when the spend callable grants access and the gated work only navigates.
  final bool refundOnFailure;

  /// Error text for rewarded-ad credit or upsell exceptions. Unchanged credits use the standard credit error.
  final String? adErrorMessage;
  final String? spendErrorMessage;
  final String? failureLabel;
  final String refundReason;
  final void Function(String spendTag)? onAttempt;
  final VoidCallback? onWatchChosen;

  /// Called with the ledger id of a tracked download right after its charge, before the mounted check, so a caller that
  /// has left the screen still learns it. The gate settles that id on every way out: [perform] succeeded or a refund was
  /// confirmed clears it, anything else releases it to recovery.
  final void Function(String txId)? onPaid;

  /// Called when coins really left the balance, before [perform].
  final void Function(String spendTag, CoinMutationResult result)? onSpent;

  /// Build the next gate attempt after an ad was credited. Null means try once, then return if still insufficient.
  final CoinGateSpec Function()? retrySpec;

  /// False makes Pro users go through the spend too, for sinks that Pro pays for.
  final bool premiumBypass;
}

/// One place for the premium bypass, spend, low-balance sheet, rewarded ad, credit, retry, refund sequence.
class CoinGate {
  CoinGate(this._port, {AppLocalizations? l10n}) : _l10n = l10n ?? AppLocalizationsEn();

  factory CoinGate.forContext(BuildContext context) =>
      CoinGate(AppCoinGatePort(() => context.read<AdsBloc>()), l10n: context.l10n);

  final CoinGatePort _port;
  final AppLocalizations _l10n;

  /// [startInsufficient] opens the low-balance prompt first when the balance is short, as after an ad that did not
  /// cover the cost.
  Future<CoinGateResult> run(CoinGateSpec spec, {bool startInsufficient = false}) async {
    if (!spec.isMounted()) {
      return CoinGateResult.cancelled;
    }
    if (_premiumShortcut(spec)) {
      return await _perform(spec, 'premium_bypass') ? CoinGateResult.performedFree : CoinGateResult.failedNotRefunded;
    }

    final int cost = spec.action.cost();
    CoinGatePrompt? prompt;
    final int? nudgeBelow = spec.nudgeBelow;
    final int balance = _port.balance;
    final bool low = nudgeBelow != null && balance < nudgeBelow;
    if (startInsufficient && balance < cost) {
      prompt = CoinGatePrompt(phase: CoinGatePhase.insufficient, cost: cost, balance: balance);
    } else if (low || spec.confirmFirst) {
      prompt = CoinGatePrompt(phase: CoinGatePhase.nudge, cost: cost, balance: balance);
    } else if (spec.precheckBalance && balance < cost) {
      prompt = CoinGatePrompt(phase: CoinGatePhase.insufficient, cost: cost, balance: balance);
    }
    String spendTag = spec.tags.spend;

    while (true) {
      if (_premiumShortcut(spec)) {
        return await _perform(spec, 'premium_bypass') ? CoinGateResult.performedFree : CoinGateResult.failedNotRefunded;
      }
      bool nudgeSpendSelected = false;
      if (prompt != null) {
        if (!spec.isMounted()) {
          return CoinGateResult.cancelled;
        }
        final CoinGatePrompt current = prompt;
        prompt = null;
        final bool shouldLogInsufficient =
            current.phase == CoinGatePhase.insufficient && (!spec.logInsufficientOnlyWhenLow || _port.balance < cost);
        if (shouldLogInsufficient || (current.phase == CoinGatePhase.nudge && low)) {
          _port.logLowBalanceNudge(
            sourceTag: current.phase == CoinGatePhase.nudge
                ? spec.tags.nudge ?? spec.tags.insufficient
                : spec.tags.insufficient,
            requiredCoins: cost,
          );
        }
        final CoinGateChoice choice = await spec.choose(await _withAdState(current));
        if (!spec.isMounted()) {
          return CoinGateResult.cancelled;
        }
        switch (choice) {
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
            nudgeSpendSelected = current.phase == CoinGatePhase.nudge;
            spendTag =
                spec.tags.promptSpend ??
                (current.phase == CoinGatePhase.nudge ? spec.tags.nudgeSpend ?? spec.tags.spend : spec.tags.spend);
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

      if (_premiumShortcut(spec)) {
        return await _perform(spec, 'premium_bypass') ? CoinGateResult.performedFree : CoinGateResult.failedNotRefunded;
      }
      final CoinGateResult result = await _spendAndPerform(spec, spendTag);
      if (result != CoinGateResult.insufficient) {
        return result;
      }
      if (!spec.isMounted()) {
        return CoinGateResult.cancelled;
      }
      if (spec.toastWhenInsufficient) {
        _port.showError('Need ${(cost - _port.balance).clamp(1, cost)} more coins.');
      }
      if (nudgeSpendSelected && !spec.repromptOnNudgeSpendInsufficient) {
        return result;
      }
      prompt = CoinGatePrompt(phase: CoinGatePhase.insufficient, cost: cost, balance: _port.balance);
    }
  }

  /// Pro runs the action free only for actions in the config bypass set, as the server does.
  bool _premiumShortcut(CoinGateSpec spec) =>
      _port.isPremium &&
      spec.spend == null &&
      spec.premiumBypass &&
      EconomyConfig.current.proBypassActions.contains(spec.action.name);

  Future<CoinGatePrompt> _withAdState(CoinGatePrompt prompt) async {
    bool adsAllowed = true;
    try {
      adsAllowed = await _port.adsAllowed();
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: 'coins.gate.ads_allowed', error: error, stackTrace: stackTrace);
    }
    return CoinGatePrompt(
      phase: prompt.phase,
      cost: prompt.cost,
      balance: prompt.balance,
      adsAllowed: adsAllowed,
      adsRemaining: _port.adsRemaining,
    );
  }

  /// Earn-only path: watch a rewarded ad and credit the coins. Returns true when the coins landed.
  Future<bool> watchAdForCoins({
    required String sourceTag,
    required String upsellSource,
    required bool Function() isMounted,
    bool creditAfterUnmount = true,
    String? adErrorMessage,
  }) async {
    if (!isMounted()) {
      return false;
    }
    final RewardedAdResult watched;
    try {
      watched = await _port.watchRewardedAdResult();
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: sourceTag, error: error, stackTrace: stackTrace);
      if (isMounted()) {
        _port.showError(adFailureMessage(_l10n, null));
      }
      return false;
    }
    if (!watched.earned) {
      if (isMounted()) {
        _port.showError(adFailureMessage(_l10n, watched.failure));
      }
      return false;
    }
    if (!creditAfterUnmount && !isMounted()) {
      return false;
    }
    final CoinMutationResult credit;
    try {
      credit = await _port.award(CoinEarnAction.rewardedAd, sourceTag: sourceTag);
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: sourceTag, error: error, stackTrace: stackTrace);
      if (isMounted()) {
        _port.showError(adErrorMessage ?? _l10n.economyAdCreditFailure);
      }
      return false;
    }
    if (!credit.changed) {
      if (isMounted()) {
        if (credit.unknownOutcomeTransactionId.isNotEmpty) {
          _port.showInfo(rewardPendingMessage(_l10n));
        } else {
          _port.showError(creditFailureMessage(_l10n, credit));
        }
      }
      return false;
    }
    if (isMounted()) {
      try {
        await _port.recordRewardedAdWatch(source: upsellSource);
      } catch (error, stackTrace) {
        _port.logCoinError(sourceTag: sourceTag, error: error, stackTrace: stackTrace);
        if (isMounted()) {
          _port.showError(adErrorMessage ?? _l10n.economyAdCreditFailure);
        }
        return false;
      }
    }
    return true;
  }

  Future<CoinGateResult> _watchAndRetry(CoinGateSpec spec, int cost) async {
    spec.onWatchChosen?.call();
    final bool credited = await watchAdForCoins(
      sourceTag: spec.tags.ad,
      upsellSource: spec.upsellSource,
      isMounted: spec.isMounted,
      creditAfterUnmount: spec.creditAfterUnmount,
      adErrorMessage: spec.adErrorMessage,
    );
    if (!credited) {
      return CoinGateResult.cancelled;
    }
    if (!spec.isMounted()) {
      return CoinGateResult.cancelled;
    }
    final CoinGateSpec Function()? retrySpec = spec.retrySpec;
    if (retrySpec != null) {
      return run(retrySpec());
    }
    if (_port.balance < cost) {
      return run(spec, startInsufficient: true);
    }
    return _spendAndPerform(spec, spec.tags.retrySpend ?? spec.tags.spend);
  }

  Future<CoinGateResult> _spendAndPerform(CoinGateSpec spec, String tag) async {
    spec.onAttempt?.call(tag);
    final CoinMutationResult spent;
    try {
      spent =
          await (spec.spend?.call(tag) ??
              _port.spend(
                spec.action,
                sourceTag: tag,
                reason: spec.reason,
                label: spec.label,
                pendingDownloadLink: spec.pendingDownloadLink,
              ));
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: tag, error: error, stackTrace: stackTrace);
      if (spec.isMounted()) {
        _port.showError(spec.spendErrorMessage ?? _l10n.economyCoinSpendFailed);
      }
      return CoinGateResult.spendFailed;
    }
    if (!spent.success) {
      if (spent.insufficientBalance) {
        return CoinGateResult.insufficient;
      }
      if (spec.isMounted()) {
        _port.showError(spec.spendErrorMessage ?? _l10n.economyCoinSpendFailed);
      }
      return CoinGateResult.spendFailed;
    }
    final String txId = spent.changed ? spent.pendingDownloadTxId : '';
    if (txId.isNotEmpty) {
      try {
        spec.onPaid?.call(txId);
      } catch (error, stackTrace) {
        _port.logCoinError(sourceTag: tag, error: error, stackTrace: stackTrace);
      }
    }
    if (!spec.isMounted()) {
      if (spent.changed && spec.refundOnFailure) {
        return _refund(spec, tag, spent, txId);
      }
      await _release(tag, txId);
      return spent.changed ? CoinGateResult.performed : CoinGateResult.failedNotRefunded;
    }
    if (spent.changed) {
      try {
        spec.onSpent?.call(tag, spent);
      } catch (error, stackTrace) {
        _port.logCoinError(sourceTag: tag, error: error, stackTrace: stackTrace);
      }
    }
    if (await _perform(spec, tag)) {
      await _clear(tag, txId);
      return CoinGateResult.performed;
    }
    if (spent.changed && spec.refundOnFailure) {
      return _refund(spec, tag, spent, txId);
    }
    await _release(tag, txId);
    return CoinGateResult.failedNotRefunded;
  }

  Future<bool> _perform(CoinGateSpec spec, String tag) async {
    if (!spec.isMounted()) {
      return false;
    }
    try {
      return await spec.perform();
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: tag, error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<CoinGateResult> _refund(CoinGateSpec spec, String tag, CoinMutationResult spent, String txId) async {
    final String refundTag = '$tag.refund';
    try {
      final CoinMutationResult refund = await _port.refundSpend(
        spec.action,
        sourceTag: refundTag,
        transactionId: spent.transactionId,
        reason: spec.refundReason,
      );
      if (refund.success && refund.changed) {
        await _clear(tag, txId);
        if (spec.isMounted()) {
          _port.showSuccess(
            _l10n.economyCoinGateRefunded(spec.failureLabel ?? _l10n.economyDownloadFailedLabel, refund.delta),
          );
        }
        return CoinGateResult.failedRefunded;
      }
      _port.logCoinError(sourceTag: refundTag, error: StateError('Coin refund was not applied: ${refund.reason}'));
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: refundTag, error: error, stackTrace: stackTrace);
    }
    await _release(tag, txId);
    if (spec.isMounted()) {
      _port.showError(_l10n.economyCoinGateRefundUnconfirmed(spec.failureLabel ?? _l10n.economyDownloadFailedLabel));
    }
    return CoinGateResult.failedNotRefunded;
  }

  Future<void> _clear(String tag, String txId) async {
    if (txId.isEmpty) return;
    try {
      await _port.clearPendingDownload(txId);
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: '$tag.ledger_clear', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _release(String tag, String txId) async {
    if (txId.isEmpty) return;
    try {
      await _port.releasePendingDownload(txId);
    } catch (error, stackTrace) {
      _port.logCoinError(sourceTag: '$tag.ledger_release', error: error, stackTrace: stackTrace);
    }
  }
}

/// What to tell the user when no rewarded ad played.
String adFailureMessage(AppLocalizations l10n, AdFailureReason? reason) => switch (reason) {
  AdFailureReason.consent => l10n.economyAdsOffPrivacy,
  AdFailureReason.noFill => l10n.economyAdUnavailable,
  AdFailureReason.offline => l10n.economyAdOffline,
  _ => l10n.economyAdNotCompleted,
};

String rewardPendingMessage(AppLocalizations l10n) => l10n.economyAdRewardPending;

/// What to tell the user when a watched ad did not add coins.
String creditFailureMessage(AppLocalizations l10n, CoinMutationResult credit) => switch (credit.reason) {
  'rewarded_ad_limit' => l10n.economyAdDailyLimit,
  _ => l10n.economyAdCreditFailure,
};
