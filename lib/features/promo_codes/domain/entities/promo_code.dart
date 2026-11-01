String _snakeCase(String name) => name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

enum PromoRewardType {
  coins,
  premiumDays;

  String get wireValue => _snakeCase(name);
}

sealed class PromoReward {
  const PromoReward();

  PromoRewardType get type;
}

final class CoinsReward extends PromoReward {
  const CoinsReward(this.coins);

  final int coins;

  @override
  PromoRewardType get type => PromoRewardType.coins;
}

final class PremiumDaysReward extends PromoReward {
  const PremiumDaysReward(this.days, {this.until});

  final int days;
  final DateTime? until;

  @override
  PromoRewardType get type => PromoRewardType.premiumDays;
}

/// One value per server `reason` from the redeemCode callable, plus the failures the client sees on its own.
enum RedeemFailureReason {
  invalidCode,
  notFound,
  disabled,
  expired,
  limitReached,
  alreadyRedeemed,
  accountTooNew,
  newUsersOnly,
  premiumNotOnIos,
  alreadyPremium,
  rateLimited,
  busy,
  signedOut,
  network,
  unknown;

  String get wireValue => _snakeCase(name);

  static RedeemFailureReason fromWire(Object? value) =>
      RedeemFailureReason.values.firstWhere((reason) => reason.wireValue == value, orElse: () => unknown);
}

sealed class RedeemOutcome {
  const RedeemOutcome();
}

final class RedeemSucceeded extends RedeemOutcome {
  const RedeemSucceeded(this.reward, {this.coinBalance, this.replayed = false});

  final PromoReward reward;

  /// The balance after a coin code, from the server.
  final int? coinBalance;

  /// True when the server returned a stored result for an earlier request. Its totals may now be stale.
  final bool replayed;
}

final class RedeemFailed extends RedeemOutcome {
  const RedeemFailed(this.reason);

  final RedeemFailureReason reason;
}

enum RedeemSheetSource {
  settings,
  rewards,
  link;

  String get wireValue => name;
}

enum StoreCodePlatform {
  ios,
  android;

  String get wireValue => name;
}
