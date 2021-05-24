import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  bool loadingAd;
  bool adLoaded;
  RewardedAd? rewardedAd;
  AdHelper({this.loadingAd = false, this.adLoaded = false, this.rewardedAd});
}
