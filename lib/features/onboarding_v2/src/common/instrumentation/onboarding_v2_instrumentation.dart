import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';

class OnboardingV2Instrumentation {
  const OnboardingV2Instrumentation._();

  static void trackInterestsCompleted(int selectedCount) {
    analytics.track(OnboardingV2InterestsCompletedEvent(selectedCount: selectedCount));
  }

  static void trackStarterPackCompleted(int followedCount) {
    analytics.track(OnboardingV2StarterPackCompletedEvent(followedCount: followedCount));
  }

  static void trackFirstWallpaperShown() {
    analytics.track(const OnboardingV2FirstWallpaperShownEvent());
  }

  static void trackFirstWallpaperAction({required bool success, required int elapsedMs, required String platform}) {
    analytics.track(
      OnboardingV2FirstWallpaperActionEvent(
        result: success ? BinaryResultValue.success : BinaryResultValue.failure,
        elapsedMs: elapsedMs,
        platform: platform,
      ),
    );
  }

  static void trackPaywallTimerUnlocked() {
    analytics.track(const OnboardingV2PaywallTimerUnlockedEvent());
  }

  static void trackCompleted({required bool didPurchase, required int totalElapsedMs}) {
    analytics.track(OnboardingV2CompletedEvent(didPurchase: didPurchase, totalElapsedMs: totalElapsedMs));
  }
}
