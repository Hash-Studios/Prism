import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/economy_config.dart';

enum AiQualityTier {
  fast('Fast'),
  balanced('Balanced'),
  quality('Quality');

  const AiQualityTier(this.label);

  final String label;

  /// The list price from the loaded economy config.
  int get coinCost => switch (this) {
    AiQualityTier.fast => CoinPolicy.aiGenerationFast,
    AiQualityTier.balanced => CoinPolicy.aiGenerationBalanced,
    AiQualityTier.quality => CoinPolicy.aiGenerationQuality,
  };

  /// What the user pays: Pro pays half, rounded up.
  int costFor({required bool isPro}) => proPrice(coinCost, isPro);

  String get apiValue => name;

  static AiQualityTier fromApiValue(String value) => values.asNameMap()[value.trim().toLowerCase()] ?? balanced;
}
