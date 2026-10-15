import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';
import 'package:Prism/features/ads/biz/rewarded_ad_flow.dart' as flow;
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

/// Everything the coin gate needs from the outside world. Production uses [AppCoinGatePort]; tests use a fake.
abstract interface class CoinGatePort {
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
  AppCoinGatePort(this._ads);

  final AdsBloc Function() _ads;

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
