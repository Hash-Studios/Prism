import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/ads/biz/coin_gate_port.dart';

/// In-memory [CoinGatePort]. Spends and awards move [balance]. Records every call in [log] and every toast.
class FakeCoinGatePort implements CoinGatePort {
  FakeCoinGatePort({this.balance = 0, this.isPremium = false});

  @override
  int balance;
  @override
  bool isPremium;

  final List<String> log = <String>[];
  final List<String> errors = <String>[];
  final List<String> successes = <String>[];

  int awardAmount = CoinPolicy.rewardedAd;
  bool adCompletes = true;
  bool spendThrows = false;
  bool awardThrows = false;
  bool awardChanges = true;
  bool refundApplies = true;

  @override
  Future<bool> watchRewardedAd() async {
    log.add('ad');
    return adCompletes;
  }

  @override
  Future<CoinMutationResult> spend(CoinSpendAction action, {required String sourceTag, String? reason}) async {
    log.add('spend:$sourceTag');
    if (spendThrows) throw StateError('spend failed');
    final int cost = action.cost();
    if (balance < cost) {
      return CoinMutationResult(
        success: false,
        changed: false,
        previousBalance: balance,
        currentBalance: balance,
        delta: 0,
        insufficientBalance: true,
      );
    }
    final int previous = balance;
    balance -= cost;
    return CoinMutationResult(
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: balance,
      delta: -cost,
      transactionId: 'tx-$sourceTag',
    );
  }

  @override
  Future<CoinMutationResult> award(CoinEarnAction action, {required String sourceTag}) async {
    log.add('award:$sourceTag');
    if (awardThrows) throw StateError('award failed');
    if (!awardChanges) return CoinMutationResult.noChange(balance: balance);
    final int reward = awardAmount;
    final int previous = balance;
    balance += reward;
    return CoinMutationResult(
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: balance,
      delta: reward,
    );
  }

  @override
  Future<CoinMutationResult> refundSpend(
    CoinSpendAction action, {
    required String sourceTag,
    required String transactionId,
    required String reason,
  }) async {
    log.add('refund:$sourceTag:$transactionId:$reason');
    if (!refundApplies) return CoinMutationResult.noChange(balance: balance, success: false, reason: 'refused');
    final int previous = balance;
    balance += action.cost();
    return CoinMutationResult(
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: balance,
      delta: action.cost(),
    );
  }

  @override
  Future<void> recordRewardedAdWatch({required String source}) async => log.add('watch:$source');

  @override
  Future<void> presentLowBalancePaywall({required String source}) async => log.add('paywall:$source');

  @override
  void logLowBalanceNudge({required String sourceTag, required int requiredCoins}) =>
      log.add('nudge:$sourceTag:$requiredCoins');

  @override
  void logCoinError({required String sourceTag, required Object error, StackTrace? stackTrace}) =>
      log.add('error:$sourceTag');

  @override
  void showError(String message) => errors.add(message);

  @override
  void showSuccess(String message) => successes.add(message);
}
