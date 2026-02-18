class AdsEntity {
  const AdsEntity({
    required this.downloadCoins,
    required this.loadingAd,
    required this.adLoaded,
    required this.adFailed,
  });

  final num downloadCoins;
  final bool loadingAd;
  final bool adLoaded;
  final bool adFailed;

  static const AdsEntity empty = AdsEntity(downloadCoins: 0, loadingAd: false, adLoaded: false, adFailed: false);

  AdsEntity copyWith({num? downloadCoins, bool? loadingAd, bool? adLoaded, bool? adFailed}) {
    return AdsEntity(
      downloadCoins: downloadCoins ?? this.downloadCoins,
      loadingAd: loadingAd ?? this.loadingAd,
      adLoaded: adLoaded ?? this.adLoaded,
      adFailed: adFailed ?? this.adFailed,
    );
  }
}
