class AdsEntity {
  const AdsEntity({
    required this.rewardEarned,
    required this.loadingAd,
    required this.adLoaded,
    required this.adFailed,
  });

  final bool rewardEarned;
  final bool loadingAd;
  final bool adLoaded;
  final bool adFailed;

  static const AdsEntity empty = AdsEntity(rewardEarned: false, loadingAd: false, adLoaded: false, adFailed: false);

  AdsEntity copyWith({bool? rewardEarned, bool? loadingAd, bool? adLoaded, bool? adFailed}) {
    return AdsEntity(
      rewardEarned: rewardEarned ?? this.rewardEarned,
      loadingAd: loadingAd ?? this.loadingAd,
      adLoaded: adLoaded ?? this.adLoaded,
      adFailed: adFailed ?? this.adFailed,
    );
  }
}
