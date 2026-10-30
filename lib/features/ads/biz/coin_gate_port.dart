import 'dart:async';

import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';
import 'package:Prism/features/ads/biz/rewarded_ad_flow.dart' as flow;
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/data/repositories/ads_repository_impl.dart';
import 'package:Prism/features/ads/domain/repositories/ads_repository.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

/// Everything the coin gate needs from the outside world. Production uses [AppCoinGatePort]; tests use a fake.
abstract interface class CoinGatePort {
  Future<CoinMutationResult> watchVerifiedReward(String placement);
  bool get isPremium;
  int get balance;

  /// Rewarded ads the user can still watch today, when the server has said so.
  int? get adsRemaining;

  /// False when the user refused ad consent, so no ad can play.
  Future<bool> adsAllowed();

  /// Loads and shows a rewarded ad. The result says whether the user earned it, and why not when no ad played.
  Future<flow.RewardedAdResult> watchRewardedAdResult();
  Future<CoinMutationResult> spend(
    CoinSpendAction action, {
    required String sourceTag,
    String? reason,
    String? label,
    String? pendingDownloadLink,
  });
  Future<CoinMutationResult> award(CoinEarnAction action, {required String sourceTag});
  Future<CoinMutationResult> refundSpend(
    CoinSpendAction action, {
    required String sourceTag,
    required String transactionId,
    required String reason,
  });

  /// Removes the ledger entry of a paid download whose save finished or whose refund was confirmed.
  Future<void> clearPendingDownload(String txId);

  /// Hands a paid download that ended with no confirmed save and no confirmed refund to recovery.
  Future<void> releasePendingDownload(String txId);
  Future<void> recordRewardedAdWatch({required String source});
  Future<void> presentLowBalancePaywall({required String source});
  void logLowBalanceNudge({required String sourceTag, required int requiredCoins});
  void logCoinError({required String sourceTag, required Object error, StackTrace? stackTrace});
  void showError(String message);
  void showSuccess(String message);
  void showInfo(String message);
}

class AppCoinGatePort implements CoinGatePort {
  /// [ads] is read lazily so a gate can run without an [AdsBloc] until an ad is actually needed.
  AppCoinGatePort(this._ads, {this.confirmRewardQuote, this.isPresentationCurrent});

  final AdsBloc Function() _ads;
  final Future<bool> Function(int rewardCoins)? confirmRewardQuote;
  final bool Function()? isPresentationCurrent;
  static bool _watching = false;

  @override
  Future<CoinMutationResult> watchVerifiedReward(String placement) => _watchVerifiedReward(placement);

  Future<CoinMutationResult> _watchVerifiedReward(String placement) async {
    CoinMutationResult pending() => CoinMutationResult.noChange(
      balance: balance,
      success: false,
      reason: 'reward_pending',
      unknownOutcomeTransactionId: 'verified_session',
    );
    if (_watching) return pending();
    _watching = true;
    bool fullscreenStarted = false;
    final int displayedEstimate = CoinsService.instance.adsRewardNow;
    try {
      final session = await CoinsService.instance.beginRewardedSession(placement);
      if (session == null) {
        final String? reason = CoinsService.instance.rewardedSessionUnavailableReason;
        return reason == null
            ? pending()
            : CoinMutationResult.noChange(
                balance: balance,
                success: false,
                reason: reason == 'daily_limit' ? 'rewarded_ad_limit' : 'ad_noFill',
              );
      }
      if (session.rewardCoins != displayedEstimate && !(await confirmRewardQuote?.call(session.rewardCoins) ?? false)) {
        return CoinMutationResult.noChange(balance: balance, success: false, reason: 'reward_quote_cancelled');
      }
      final repository = getIt<AdsRepository>();
      if (repository is! AdsRepositoryImpl) return pending();
      final loaded = await repository.prepareSession(session, placement: session.placement);
      if (loaded.data?.adLoaded != true) {
        return CoinMutationResult.noChange(
          balance: balance,
          success: false,
          reason: 'ad_${loaded.data?.failureReason?.name ?? 'other'}',
        );
      }
      if (!(isPresentationCurrent?.call() ?? true)) {
        return CoinMutationResult.noChange(balance: balance, success: false, reason: 'reward_quote_cancelled');
      }
      Future<CoinMutationResult> finishFullscreen() async {
        final shown = await repository.showRewardedAd();
        await CoinsService.instance.reconcileRewardedSession();
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (shown.data?.rewardPending == true &&
            app_state.prismUser.id == session.userId &&
            !CoinsService.instance.rewardSessionSettled(session.sessionId) &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (app_state.prismUser.id != session.userId) break;
          await CoinsService.instance.reconcileRewardedSession();
        }
        final bool settled =
            app_state.prismUser.id == session.userId && CoinsService.instance.rewardSessionSettled(session.sessionId);
        final int rewardCoins = settled ? CoinsService.instance.confirmedRewardCoins(session.sessionId) : 0;
        return settled
            ? CoinMutationResult(
                success: true,
                changed: true,
                previousBalance: balance - rewardCoins,
                currentBalance: balance,
                delta: rewardCoins,
              )
            : shown.data?.rewardPending == true
            ? pending()
            : CoinMutationResult.noChange(balance: balance, success: false, reason: 'ad_not_completed');
      }

      fullscreenStarted = true;
      final completion = finishFullscreen().whenComplete(() => _watching = false);
      return await completion.timeout(const Duration(seconds: 60), onTimeout: pending);
    } finally {
      if (!fullscreenStarted) _watching = false;
    }
  }

  @override
  bool get isPremium => app_state.prismUser.premium;

  @override
  int get balance => CoinsService.instance.balanceNotifier.value;

  @override
  int? get adsRemaining => CoinsService.instance.adsRemainingToday;

  @override
  Future<bool> adsAllowed() => AdConsent.instance.ensure();

  @override
  Future<flow.RewardedAdResult> watchRewardedAdResult() => flow.watchRewardedAdResult(_ads());

  @override
  Future<CoinMutationResult> spend(
    CoinSpendAction action, {
    required String sourceTag,
    String? reason,
    String? label,
    String? pendingDownloadLink,
  }) => CoinsService.instance.spend(
    action,
    sourceTag: sourceTag,
    reason: reason,
    label: label,
    pendingDownloadLink: pendingDownloadLink,
  );

  @override
  Future<CoinMutationResult> award(CoinEarnAction action, {required String sourceTag}) =>
      CoinsService.instance.award(action, sourceTag: sourceTag);

  @override
  Future<CoinMutationResult> refundSpend(
    CoinSpendAction action, {
    required String sourceTag,
    required String transactionId,
    required String reason,
  }) => CoinsService.instance.refundSpend(action, sourceTag: sourceTag, transactionId: transactionId, reason: reason);

  @override
  Future<void> clearPendingDownload(String txId) => CoinsService.instance.clearPendingDownload(txId);

  @override
  Future<void> releasePendingDownload(String txId) => CoinsService.instance.releasePendingDownload(txId);

  @override
  Future<void> recordRewardedAdWatch({required String source}) =>
      PaywallOrchestrator.instance.recordRewardedAdWatchAndMaybeUpsell(source: source);

  @override
  Future<void> presentLowBalancePaywall({required String source}) =>
      PaywallOrchestrator.instance.present(placement: PaywallPlacement.lowBalance, source: source);

  @override
  void logLowBalanceNudge({required String sourceTag, required int requiredCoins}) =>
      CoinsService.instance.logLowBalanceNudge(sourceTag: sourceTag, requiredCoins: requiredCoins);

  @override
  void logCoinError({required String sourceTag, required Object error, StackTrace? stackTrace}) =>
      CoinsService.instance.logCoinError(sourceTag: sourceTag, error: error, stackTrace: stackTrace);

  @override
  void showError(String message) => toasts.error(message);

  @override
  void showSuccess(String message) => toasts.success(message);

  @override
  void showInfo(String message) => toasts.info(message);
}
