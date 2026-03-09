part of 'onboarding_v2_bloc.j.dart';

@freezed
abstract class OnboardingV2Event with _$OnboardingV2Event {
  const factory OnboardingV2Event.started() = _Started;
  const factory OnboardingV2Event.authCompleted() = _AuthCompleted;
  const factory OnboardingV2Event.authLoadingChanged({required bool isLoading}) = _AuthLoadingChanged;
  const factory OnboardingV2Event.interestToggled(String categoryName) = _InterestToggled;
  const factory OnboardingV2Event.interestsConfirmed() = _InterestsConfirmed;
  const factory OnboardingV2Event.creatorFollowToggled(String creatorEmail) = _CreatorFollowToggled;
  const factory OnboardingV2Event.starterPackConfirmed() = _StarterPackConfirmed;
  const factory OnboardingV2Event.firstWallpaperActionRequested() = _FirstWallpaperActionRequested;
  const factory OnboardingV2Event.firstWallpaperActionCompleted({required bool success, required int elapsedMs}) =
      _FirstWallpaperActionCompleted;
  const factory OnboardingV2Event.firstWallpaperStepContinued() = _FirstWallpaperStepContinued;
  const factory OnboardingV2Event.paywallTimerTicked() = _PaywallTimerTicked;
  const factory OnboardingV2Event.paywallPrimaryTapped() = _PaywallPrimaryTapped;
  const factory OnboardingV2Event.paywallContinueFreeTapped() = _PaywallContinueFreeTapped;
  const factory OnboardingV2Event.paywallResultReceived({required bool didPurchase}) = _PaywallResultReceived;
  const factory OnboardingV2Event.stepBack() = _StepBack;
}
