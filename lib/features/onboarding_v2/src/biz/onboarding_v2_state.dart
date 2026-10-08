part of 'onboarding_v2_bloc.j.dart';

enum OnboardingV2Step { auth, interests, starterPack, aiGenerate, firstWallpaper }

enum OnboardingV2NavRequest { openPaywall, completeOnboarding, openDashboardAsGuest, exitApp }

enum FirstWallpaperStatus { idle, loading, success, failure }

enum AiGenerateStatus { idle, loading, success, failure }

@freezed
abstract class OnboardingInterestsData with _$OnboardingInterestsData {
  const OnboardingInterestsData._();

  // ignore: sort_unnamed_constructors_first
  const factory OnboardingInterestsData({
    required List<String> available,
    required List<String> selected,
    required Map<String, String> categoryImages,
  }) = _OnboardingInterestsData;

  factory OnboardingInterestsData.initial() =>
      const OnboardingInterestsData(available: [], selected: [], categoryImages: {});

  /// Fewer categories than the minimum must not block the user, so the bar drops to what exists.
  int get requiredCount => math.min(OnboardingV2Config.minInterests, available.length);

  bool get canContinue => requiredCount > 0 && selected.length >= requiredCount;
}

@freezed
abstract class OnboardingStarterPackData with _$OnboardingStarterPackData {
  const OnboardingStarterPackData._();

  // ignore: sort_unnamed_constructors_first
  const factory OnboardingStarterPackData({
    required List<OnboardingStarterCreatorEntity> creators,
    required Set<String> selectedEmails,
  }) = _OnboardingStarterPackData;

  factory OnboardingStarterPackData.initial() => const OnboardingStarterPackData(creators: [], selectedEmails: {});

  int get requiredCount => math.min(OnboardingV2Config.minFollows, creators.length);

  bool get canContinue => requiredCount > 0 && selectedEmails.length >= requiredCount;
}

@freezed
abstract class OnboardingAiData with _$OnboardingAiData {
  const factory OnboardingAiData({
    required String prompt,
    required AiStylePreset stylePreset,
    required AiGenerateStatus status,
    String? imageUrl,
    String? thumbnailUrl,
  }) = _OnboardingAiData;

  factory OnboardingAiData.initial() =>
      const OnboardingAiData(prompt: '', stylePreset: AiStylePreset.abstract, status: AiGenerateStatus.idle);
}

@freezed
abstract class OnboardingWallpaperData with _$OnboardingWallpaperData {
  const factory OnboardingWallpaperData({
    OnboardingWallpaperVm? wallpaper,
    required FirstWallpaperStatus status,

    /// Why the last action failed. `PHOTO_PERMISSION_DENIED` on iOS means Photos access is off.
    String? errorCode,

    /// The screen the wallpaper was set on (Android).
    WallpaperTarget? target,
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
    required OnboardingAiData aiData,
    required bool skipInterests,
    required bool skipStarterPack,

    /// iOS guest path: the user browses without an account and only picks interests.
    required bool isGuest,
    OnboardingV2NavRequest? navRequest,
  }) = _OnboardingV2State;

  factory OnboardingV2State.initial() => OnboardingV2State(
    step: OnboardingV2Step.auth,
    loadStatus: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    isAuthLoading: false,
    interestsData: OnboardingInterestsData.initial(),
    starterPackData: OnboardingStarterPackData.initial(),
    wallpaperData: OnboardingWallpaperData.initial(),
    aiData: OnboardingAiData.initial(),
    skipInterests: false,
    skipStarterPack: false,
    isGuest: false,
  );
}
