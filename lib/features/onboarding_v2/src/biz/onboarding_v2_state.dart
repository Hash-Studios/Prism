part of 'onboarding_v2_bloc.j.dart';

enum OnboardingV2Step { auth, interests, starterPack, firstWallpaper }

enum OnboardingV2NavRequest { openPaywall, completeOnboarding }

enum FirstWallpaperStatus { idle, loading, success, failure }

@freezed
abstract class OnboardingInterestsData with _$OnboardingInterestsData {
  const OnboardingInterestsData._();

  const factory OnboardingInterestsData({
    required List<String> available,
    required List<String> selected,
    required Map<String, String> categoryImages,
  }) = _OnboardingInterestsData;

  factory OnboardingInterestsData.initial() =>
      const OnboardingInterestsData(available: [], selected: [], categoryImages: {});

  bool get canContinue => selected.length >= OnboardingV2Config.minInterests;
}

@freezed
abstract class OnboardingStarterPackData with _$OnboardingStarterPackData {
  const OnboardingStarterPackData._();

  const factory OnboardingStarterPackData({
    required List<OnboardingCreatorVm> creators,
    required List<String> selectedEmails,
  }) = _OnboardingStarterPackData;

  factory OnboardingStarterPackData.initial() => const OnboardingStarterPackData(creators: [], selectedEmails: []);

  bool get canContinue => selectedEmails.length >= OnboardingV2Config.minFollows;
}

@freezed
abstract class OnboardingWallpaperData with _$OnboardingWallpaperData {
  const factory OnboardingWallpaperData({
    OnboardingWallpaperVm? wallpaper,
    required FirstWallpaperStatus status,
    int? elapsedMs,
  }) = _OnboardingWallpaperData;

  factory OnboardingWallpaperData.initial() => const OnboardingWallpaperData(status: FirstWallpaperStatus.idle);
}

@freezed
abstract class OnboardingV2State with _$OnboardingV2State {
  const factory OnboardingV2State({
    required OnboardingV2Step step,
    required LoadStatus loadStatus,
    required ActionStatus actionStatus,
    required bool isAuthLoading,
    required OnboardingInterestsData interestsData,
    required OnboardingStarterPackData starterPackData,
    required OnboardingWallpaperData wallpaperData,
    required bool skipInterests,
    required bool skipStarterPack,
    OnboardingV2NavRequest? navRequest,
    Failure? failure,
  }) = _OnboardingV2State;

  factory OnboardingV2State.initial() => OnboardingV2State(
    step: OnboardingV2Step.auth,
    loadStatus: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    isAuthLoading: false,
    interestsData: OnboardingInterestsData.initial(),
    starterPackData: OnboardingStarterPackData.initial(),
    wallpaperData: OnboardingWallpaperData.initial(),
    skipInterests: false,
    skipStarterPack: false,
  );
}
