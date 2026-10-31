import 'package:Prism/features/ads/data/ad_experiment_config.dart';

/// Inputs must be confirmed by the caller. Unknown values suppress the placement.
class AdExperimentEligibility {
  const AdExperimentEligibility({
    required this.completedSessions,
    required this.isFree,
    required this.consentAllowed,
    required this.activePlacement,
    required this.onboardingComplete,
  });

  final int? completedSessions;
  final bool? isFree;
  final bool? consentAllowed;
  final bool? activePlacement;
  final bool? onboardingComplete;
}

class AdExperimentPolicy {
  const AdExperimentPolicy();

  bool permits({
    required AdExperimentConfig config,
    required AdExperimentFormat format,
    required int? bucket,
    required AdExperimentEligibility eligibility,
    required int sessionImpressions,
    required bool interstitialShownToday,
    required bool successfulWallpaperAction,
    required DateTime? lastFullscreen,
    required DateTime now,
  }) {
    if (!config.enabled(format) ||
        bucket == null ||
        bucket < 20 ||
        bucket >= 100 ||
        (eligibility.completedSessions ?? -1) < 2 ||
        eligibility.isFree != true ||
        eligibility.consentAllowed != true ||
        eligibility.activePlacement != true ||
        eligibility.onboardingComplete != true) {
      return false;
    }
    if (format != AdExperimentFormat.interstitial) return sessionImpressions == 0;
    if (interstitialShownToday || !successfulWallpaperAction) return false;
    if (lastFullscreen == null) return true;
    return !now.isBefore(lastFullscreen) && now.difference(lastFullscreen) >= const Duration(minutes: 30);
  }
}
