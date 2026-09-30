enum AiChargeMode {
  freeTrial('free_trial'),
  proIncluded('pro_included'),
  coinSpend('coin_spend'),
  insufficient('insufficient');

  const AiChargeMode(this.value);

  final String value;

  static AiChargeMode fromValue(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    return values.firstWhere((mode) => mode.value == normalized, orElse: () => insufficient);
  }
}
