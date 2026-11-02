import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/economy_config.dart';

enum AiQualityTier {
  fast,
  balanced,
  quality;

  /// The list price from the loaded economy config.
  int get coinCost => switch (this) {
    AiQualityTier.fast => CoinPolicy.aiGenerationFast,
    AiQualityTier.balanced => CoinPolicy.aiGenerationBalanced,
    AiQualityTier.quality => CoinPolicy.aiGenerationQuality,
  };

  /// What the user pays. Like spendCoins, Pro pays half (rounded up) only while the config lists `aiGeneration`.
  int costFor({required bool isPro}) =>
      proPrice(coinCost, isPro && EconomyConfig.current.proDiscountActions.contains('aiGeneration'));

  String get apiValue => name;

  static AiQualityTier fromApiValue(String value) => values.asNameMap()[value.trim().toLowerCase()] ?? balanced;
}
