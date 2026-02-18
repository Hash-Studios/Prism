enum AiQualityTier {
  fast,
  balanced,
  quality;

  String get apiValue {
    switch (this) {
      case AiQualityTier.fast:
        return 'fast';
      case AiQualityTier.balanced:
        return 'balanced';
      case AiQualityTier.quality:
        return 'quality';
    }
  }

  String get label {
    switch (this) {
      case AiQualityTier.fast:
        return 'Fast';
      case AiQualityTier.balanced:
        return 'Balanced';
      case AiQualityTier.quality:
        return 'Quality';
    }
  }

  static AiQualityTier fromApiValue(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'fast':
        return AiQualityTier.fast;
      case 'quality':
        return AiQualityTier.quality;
      case 'balanced':
      default:
        return AiQualityTier.balanced;
    }
  }
}
