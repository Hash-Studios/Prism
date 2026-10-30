/// A reservation is not a payment. Only a settled server query confirms coins.
class RewardedSession {
  const RewardedSession({
    required this.sessionId,
    required this.userId,
    required this.customData,
    required this.adUnitId,
    required this.showBeforeMs,
    required this.watchId,
    required this.rewardCoins,
    required this.callbackBeforeMs,
    required this.adsRemaining,
    required this.placement,
  });
  final String sessionId;
  final String userId;
  final String customData;
  final String adUnitId;
  final int showBeforeMs;
  final String watchId;
  final int rewardCoins;
  final int callbackBeforeMs;
  final int adsRemaining;
  final String placement;
}
