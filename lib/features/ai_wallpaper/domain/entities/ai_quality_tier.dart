import 'package:Prism/core/coins/coin_policy.dart';

enum AiQualityTier {
  fast('Fast', CoinPolicy.aiGenerationFast),
  balanced('Balanced', CoinPolicy.aiGenerationBalanced),
  quality('Quality', CoinPolicy.aiGenerationQuality);

  const AiQualityTier(this.label, this.coinCost);

  final String label;
  final int coinCost;

  String get apiValue => name;

  static AiQualityTier fromApiValue(String value) => values.asNameMap()[value.trim().toLowerCase()] ?? balanced;
}
