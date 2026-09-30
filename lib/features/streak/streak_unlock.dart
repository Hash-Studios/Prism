import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

extension StreakUnlock on PrismWallpaper {
  /// A streak wallpaper opens with a long enough active streak or with enough coins.
  /// A requirement the wallpaper does not set counts as met.
  bool isUnlockedFor(StreakStatus status, int balance) {
    final streakDays = requiredStreakDays;
    final coinCost = streakShopCoinCost;
    final streakMet = streakDays == null || (status.active && status.count >= streakDays);
    final coinsMet = coinCost == null || balance >= coinCost;
    return streakMet || coinsMet;
  }
}
