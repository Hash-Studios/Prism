enum AiChargeMode {
  freeTrial,
  proIncluded,
  coinSpend,
  insufficient;

  String get value {
    switch (this) {
      case AiChargeMode.freeTrial:
        return 'free_trial';
      case AiChargeMode.proIncluded:
        return 'pro_included';
      case AiChargeMode.coinSpend:
        return 'coin_spend';
      case AiChargeMode.insufficient:
        return 'insufficient';
    }
  }

  bool get isPaid => this == AiChargeMode.coinSpend;

  static AiChargeMode fromValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'free_trial':
        return AiChargeMode.freeTrial;
      case 'pro_included':
        return AiChargeMode.proIncluded;
      case 'coin_spend':
        return AiChargeMode.coinSpend;
      case 'insufficient':
      default:
        return AiChargeMode.insufficient;
    }
  }
}
