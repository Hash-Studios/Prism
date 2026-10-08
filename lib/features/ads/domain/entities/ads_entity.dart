/// Why a rewarded ad could not be loaded. [other] covers causes the app does not name to the user.
enum AdFailureReason { consent, noFill, offline, timeout, other }

class AdsEntity {
  const AdsEntity({
    required this.rewardEarned,
    required this.loadingAd,
    required this.adLoaded,
    required this.adFailed,
    this.failureReason,
  });

  final bool rewardEarned;
  final bool loadingAd;
  final bool adLoaded;
  final bool adFailed;

  /// Only meaningful while [adFailed] is true.
  final AdFailureReason? failureReason;

  static const AdsEntity empty = AdsEntity(rewardEarned: false, loadingAd: false, adLoaded: false, adFailed: false);

  AdsEntity copyWith({
    bool? rewardEarned,
    bool? loadingAd,
    bool? adLoaded,
    bool? adFailed,
    AdFailureReason? failureReason,
  }) {
    return AdsEntity(
      rewardEarned: rewardEarned ?? this.rewardEarned,
      loadingAd: loadingAd ?? this.loadingAd,
      adLoaded: adLoaded ?? this.adLoaded,
      adFailed: adFailed ?? this.adFailed,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}
