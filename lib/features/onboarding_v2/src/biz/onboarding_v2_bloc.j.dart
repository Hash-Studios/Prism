import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/complete_onboarding_v2_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/fetch_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/follow_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/services/first_wallpaper_service.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_wallpaper_vm.j.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, visibleForTesting;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'onboarding_v2_bloc.j.freezed.dart';
part 'onboarding_v2_event.dart';
part 'onboarding_v2_state.dart';

@injectable
class OnboardingV2Bloc extends Bloc<OnboardingV2Event, OnboardingV2State> {
  OnboardingV2Bloc(
    this._fetchStarterPackUseCase,
    this._saveInterestsUseCase,
    this._followStarterPackUseCase,
    this._completeOnboardingUseCase,
    this._firstWallpaperService,
    this._categoryFeedRepository,
    this._onboardingRepository,
    this._settingsLocal,
    this._remoteConfig, {
    @ignoreParam AiGenerationRepositoryImpl? aiRepository,
  }) : _aiRepositoryOverride = aiRepository,
       super(OnboardingV2State.initial()) {
    on<_Started>(_onStarted);
    on<_LoadRetried>(_onLoadRetried);
    on<_AuthCompleted>(_onAuthCompleted);
    on<_AuthLoadingChanged>(_onAuthLoadingChanged);
    on<_InterestToggled>(_onInterestToggled);
    on<_InterestsConfirmed>(_onInterestsConfirmed);
    on<_InterestsSkipped>(_onInterestsSkipped);
    on<_CreatorFollowToggled>(_onCreatorFollowToggled);
    on<_StarterPackConfirmed>(_onStarterPackConfirmed);
    on<_StarterPackSkipped>(_onStarterPackSkipped);
    on<_FirstWallpaperActionRequested>(_onFirstWallpaperActionRequested);
    on<_FirstWallpaperActionCompleted>(_onFirstWallpaperActionCompleted);
    on<_FirstWallpaperStepContinued>(_onFirstWallpaperStepContinued);
    on<_PaywallResultReceived>(_onPaywallResultReceived);
    on<_StepBack>(_onStepBack);
    on<_AiGenerationRequested>(_onAiGenerationRequested);
    on<_AiGenerationCompleted>(_onAiGenerationCompleted);
    on<_AiGenerationStepContinued>(_onAiGenerationStepContinued);
  }

  final FetchStarterPackUseCase _fetchStarterPackUseCase;
  final SaveInterestsUseCase _saveInterestsUseCase;
  final FollowStarterPackUseCase _followStarterPackUseCase;
  final CompleteOnboardingV2UseCase _completeOnboardingUseCase;
  final FirstWallpaperService _firstWallpaperService;
  final CategoryFeedRepository _categoryFeedRepository;
  final OnboardingV2Repository _onboardingRepository;
  final SettingsLocalDataSource _settingsLocal;
  final FirebaseRemoteConfig _remoteConfig;
  final AiGenerationRepositoryImpl? _aiRepositoryOverride;

  // Built on first use: the default impl touches FirebaseAuth.instance on construction.
  late final AiGenerationRepositoryImpl _aiRepository = _aiRepositoryOverride ?? getIt<AiGenerationRepositoryImpl>();

  final math.Random _random = math.Random();

  /// Waits between the background retries of the server completion write.
  @visibleForTesting
  static List<Duration> completionRetryDelays = const <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  Stopwatch? _onboardingStopwatch;
  bool _completionInFlight = false;
  bool _completionTracked = false;
  bool _paywallHandled = false;

  Future<void> _onStarted(_Started event, Emitter<OnboardingV2State> emit) => _loadData(emit);

  Future<void> _onLoadRetried(_LoadRetried event, Emitter<OnboardingV2State> emit) => _loadData(emit);

  Future<void> _loadData(Emitter<OnboardingV2State> emit) async {
    _onboardingStopwatch ??= Stopwatch()..start();
    emit(state.copyWith(loadStatus: LoadStatus.loading, navRequest: null));
    final catalog = await PersonalizedInterestsCatalog.load(remoteConfig: _remoteConfig, settingsLocal: _settingsLocal);
    List<String> availableCategories = catalog.map((e) => e.name).toList(growable: false);
    Map<String, String> categoryImages = <String, String>{for (final entry in catalog) entry.name: entry.imageUrl};
    if (availableCategories.isEmpty) {
      final categoriesResult = await _categoryFeedRepository.getCategories();
      categoriesResult.fold(
        onSuccess: (cats) {
          final filtered = cats.where((c) => c.name != OnboardingV2Config.excludedCategory).toList(growable: false);
          availableCategories = filtered.map((c) => c.name).toList(growable: false);
          categoryImages = <String, String>{for (final entry in filtered) entry.name: entry.image};
        },
        onFailure: (_) {},
      );
    }

    final starterPackResult = await _fetchStarterPackUseCase(const NoParams());
    final List<OnboardingStarterCreatorEntity> creators = starterPackResult.fold(
      onSuccess: (entities) => [...entities]..sort((a, b) => a.rank.compareTo(b.rank)),
      onFailure: (_) => <OnboardingStarterCreatorEntity>[],
    );
    final autoSelectedEmails = creators.take(OnboardingV2Config.minFollows).map((c) => c.email).toSet();

    final wallpaperVm = await _firstWallpaperService.recommendForOnboarding(<String>[]);

    emit(
      state.copyWith(
        loadStatus: LoadStatus.success,
        interestsData: state.interestsData.copyWith(available: availableCategories, categoryImages: categoryImages),
        starterPackData: OnboardingStarterPackData(creators: creators, selectedEmails: autoSelectedEmails),
        wallpaperData: OnboardingWallpaperData(wallpaper: wallpaperVm, status: FirstWallpaperStatus.idle),
      ),
    );
    // A signed-in user who left onboarding part way resumes after sign-in.
    if (app_state.prismUser.loggedIn && state.step == OnboardingV2Step.auth) {
      add(const OnboardingV2Event.authCompleted());
    }
  }

  Future<void> _onAuthCompleted(_AuthCompleted event, Emitter<OnboardingV2State> emit) async {
    emit(state.copyWith(isAuthLoading: true, navRequest: null));

    final userId = app_state.prismUser.id;
    bool skipInterests = false;
    bool skipStarterPack = false;
    bool alreadyCompleted = false;

    if (!OnboardingV2Config.debugForceOnboarding && userId.isNotEmpty) {
      final statusResult = await _onboardingRepository.fetchUserCompletionStatus(userId: userId);
      statusResult.fold(
        onSuccess: (status) {
          skipInterests = status.hasInterests;
          skipStarterPack = status.hasFollows;
          alreadyCompleted = status.completed;
        },
        onFailure: (_) {
          // Fall back to showing all steps on error
        },
      );
    }

    if (alreadyCompleted) {
      await _skipForReturningUser(emit);
      return;
    }

    final isPremium = app_state.prismUser.premium;

    if (skipInterests && skipStarterPack) {
      // All steps already done — set skip flags then go to paywall (or complete if premium).
      emit(state.copyWith(isAuthLoading: false, skipInterests: true, skipStarterPack: true, navRequest: null));
      if (isPremium) {
        await _finishOnboarding(emit, didPurchase: false);
      } else {
        emit(state.copyWith(navRequest: OnboardingV2NavRequest.openPaywall));
      }
    } else if (skipInterests) {
      emit(
        state.copyWith(
          isAuthLoading: false,
          step: OnboardingV2Step.starterPack,
          skipInterests: true,
          skipStarterPack: false,
          navRequest: null,
        ),
      );
    } else {
      emit(
        state.copyWith(
          isAuthLoading: false,
          step: OnboardingV2Step.interests,
          skipInterests: false,
          skipStarterPack: skipStarterPack,
          navRequest: null,
        ),
      );
    }
  }

  /// The server already has `onboardingV2.completed`: restore the local flag and skip the paywall too.
  Future<void> _skipForReturningUser(Emitter<OnboardingV2State> emit) async {
    _completionTracked = true;
    try {
      await _settingsLocal.set(OnboardingV2Keys.onboardedNew, true);
    } catch (error) {
      logger.w('Could not store the onboarding flag for a returning user: $error', tag: 'OnboardingV2Bloc');
    }
    emit(
      state.copyWith(
        isAuthLoading: false,
        skipInterests: true,
        skipStarterPack: true,
        navRequest: OnboardingV2NavRequest.completeOnboarding,
      ),
    );
  }

  void _onAuthLoadingChanged(_AuthLoadingChanged event, Emitter<OnboardingV2State> emit) {
    emit(state.copyWith(isAuthLoading: event.isLoading, navRequest: null));
  }

  void _onInterestToggled(_InterestToggled event, Emitter<OnboardingV2State> emit) {
    final current = state.interestsData.selected;
    final updated = current.contains(event.categoryName)
        ? current.where((c) => c != event.categoryName).toList()
        : [...current, event.categoryName];
    emit(state.copyWith(interestsData: state.interestsData.copyWith(selected: updated), navRequest: null));
  }

  Future<void> _onInterestsConfirmed(_InterestsConfirmed event, Emitter<OnboardingV2State> emit) async {
    if (!state.interestsData.canContinue) {
      return;
    }
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, navRequest: null));

    final selectedInterests = state.interestsData.selected;
    final result = await _saveInterestsUseCase(SaveInterestsParams(interests: selectedInterests));

    if (result.isFailure) {
      emit(state.copyWith(actionStatus: ActionStatus.failure));
      return;
    }

    unawaited(analytics.track(OnboardingV2InterestsCompletedEvent(selectedCount: selectedInterests.length)));

    final refreshedWallpaper = await _firstWallpaperService.recommendForOnboarding(selectedInterests);

    final nextStep = state.skipStarterPack ? OnboardingV2Step.aiGenerate : OnboardingV2Step.starterPack;
    emit(
      state.copyWith(
        actionStatus: ActionStatus.success,
        step: nextStep,
        aiData: nextStep == OnboardingV2Step.aiGenerate ? _promptForInterests(selectedInterests) : state.aiData,
        wallpaperData: OnboardingWallpaperData(
          wallpaper: refreshedWallpaper ?? state.wallpaperData.wallpaper,
          status: FirstWallpaperStatus.idle,
        ),
      ),
    );
  }

  void _onInterestsSkipped(_InterestsSkipped event, Emitter<OnboardingV2State> emit) {
    if (state.step != OnboardingV2Step.interests) return;
    final nextStep = state.skipStarterPack ? OnboardingV2Step.aiGenerate : OnboardingV2Step.starterPack;
    emit(
      state.copyWith(
        step: nextStep,
        actionStatus: ActionStatus.idle,
        aiData: nextStep == OnboardingV2Step.aiGenerate ? _promptForInterests(const <String>[]) : state.aiData,
        navRequest: null,
      ),
    );
  }

  void _onCreatorFollowToggled(_CreatorFollowToggled event, Emitter<OnboardingV2State> emit) {
    final selected = {...state.starterPackData.selectedEmails};
    if (!selected.remove(event.creatorEmail)) selected.add(event.creatorEmail);

    emit(state.copyWith(navRequest: null, starterPackData: state.starterPackData.copyWith(selectedEmails: selected)));
  }

  Future<void> _onStarterPackConfirmed(_StarterPackConfirmed event, Emitter<OnboardingV2State> emit) async {
    if (!state.starterPackData.canContinue) {
      return;
    }
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, navRequest: null));

    final selectedCreators = state.starterPackData.creators
        .where((c) => state.starterPackData.selectedEmails.contains(c.email))
        .toList(growable: false);

    final result = await _followStarterPackUseCase(FollowStarterPackParams(creators: selectedCreators));

    if (result.isFailure) {
      emit(state.copyWith(actionStatus: ActionStatus.failure));
      return;
    }

    unawaited(analytics.track(OnboardingV2StarterPackCompletedEvent(followedCount: selectedCreators.length)));

    await _leaveStarterPack(emit);
  }

  Future<void> _onStarterPackSkipped(_StarterPackSkipped event, Emitter<OnboardingV2State> emit) async {
    if (state.step != OnboardingV2Step.starterPack) return;
    await _leaveStarterPack(emit);
  }

  Future<void> _leaveStarterPack(Emitter<OnboardingV2State> emit) async {
    if (state.skipInterests) {
      // Interests was skipped, so the wallpaper step is skipped too: go straight to the paywall.
      emit(state.copyWith(actionStatus: ActionStatus.success, navRequest: null));
      if (app_state.prismUser.premium) {
        await _finishOnboarding(emit, didPurchase: false);
      } else {
        emit(state.copyWith(navRequest: OnboardingV2NavRequest.openPaywall));
      }
    } else {
      final aiData = _promptForInterests(state.interestsData.selected);
      emit(state.copyWith(actionStatus: ActionStatus.success, step: OnboardingV2Step.aiGenerate, aiData: aiData));
    }
  }

  Future<void> _onFirstWallpaperActionRequested(
    _FirstWallpaperActionRequested event,
    Emitter<OnboardingV2State> emit,
  ) async {
    final wallpaperVm = state.wallpaperData.wallpaper;
    if (wallpaperVm == null) {
      add(const OnboardingV2Event.firstWallpaperStepContinued());
      return;
    }

    emit(
      state.copyWith(
        navRequest: null,
        wallpaperData: state.wallpaperData.copyWith(status: FirstWallpaperStatus.loading),
      ),
    );

    final actionStopwatch = Stopwatch()..start();
    final success = await _firstWallpaperService.performAction(wallpaperVm.fullUrl);
    final elapsedMs = actionStopwatch.elapsedMilliseconds;

    if (!isClosed) {
      add(OnboardingV2Event.firstWallpaperActionCompleted(success: success, elapsedMs: elapsedMs));
    }
  }

  void _onFirstWallpaperActionCompleted(_FirstWallpaperActionCompleted event, Emitter<OnboardingV2State> emit) {
    unawaited(
      analytics.track(
        OnboardingV2FirstWallpaperActionEvent(
          result: event.success ? BinaryResultValue.success : BinaryResultValue.failure,
          elapsedMs: event.elapsedMs,
          platform: defaultTargetPlatform.name.toLowerCase(),
        ),
      ),
    );
    emit(
      state.copyWith(
        wallpaperData: state.wallpaperData.copyWith(
          status: event.success ? FirstWallpaperStatus.success : FirstWallpaperStatus.failure,
        ),
      ),
    );
  }

  Future<void> _onFirstWallpaperStepContinued(
    _FirstWallpaperStepContinued event,
    Emitter<OnboardingV2State> emit,
  ) async {
    if (app_state.prismUser.premium || _paywallHandled) {
      await _finishOnboarding(emit, didPurchase: false);
    } else {
      emit(state.copyWith(navRequest: OnboardingV2NavRequest.openPaywall));
    }
  }

  Future<void> _onPaywallResultReceived(_PaywallResultReceived event, Emitter<OnboardingV2State> emit) async {
    _paywallHandled = true;
    await _finishOnboarding(emit, didPurchase: event.didPurchase);
  }

  Future<void> _finishOnboarding(Emitter<OnboardingV2State> emit, {required bool didPurchase}) async {
    if (_completionInFlight || _completionTracked) return;
    _completionInFlight = true;
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, navRequest: null));
    try {
      // The local flag goes first so a failed server write never traps the user in onboarding.
      await _settingsLocal.set(OnboardingV2Keys.onboardedNew, true);
      final totalMs = _onboardingStopwatch?.elapsedMilliseconds ?? 0;
      final result = await _completeOnboardingUseCase(const NoParams());
      if (result.isFailure) {
        unawaited(_retryCompletionInBackground(didPurchase: didPurchase, totalMs: totalMs));
        emit(state.copyWith(actionStatus: ActionStatus.failure, navRequest: OnboardingV2NavRequest.completeOnboarding));
        return;
      }
      _trackCompleted(didPurchase: didPurchase, totalMs: totalMs);
      emit(state.copyWith(actionStatus: ActionStatus.success, navRequest: OnboardingV2NavRequest.completeOnboarding));
    } finally {
      _completionInFlight = false;
    }
  }

  void _trackCompleted({required bool didPurchase, required int totalMs}) {
    _completionTracked = true;
    unawaited(analytics.track(OnboardingV2CompletedEvent(didPurchase: didPurchase, totalElapsedMs: totalMs)));
  }

  /// Runs after the screen has moved on, so it only uses the use case and analytics, never `emit`.
  Future<void> _retryCompletionInBackground({required bool didPurchase, required int totalMs}) async {
    for (final delay in completionRetryDelays) {
      await Future<void>.delayed(delay);
      try {
        final result = await _completeOnboardingUseCase(const NoParams());
        if (result.isSuccess) {
          _trackCompleted(didPurchase: didPurchase, totalMs: totalMs);
          return;
        }
      } catch (error) {
        logger.w('Onboarding completion retry failed: $error', tag: 'OnboardingV2Bloc');
      }
    }
    logger.w('Onboarding completion could not be saved to the server.', tag: 'OnboardingV2Bloc');
  }

  void _onStepBack(_StepBack event, Emitter<OnboardingV2State> emit) {
    final OnboardingV2Step? prevStep = switch (state.step) {
      OnboardingV2Step.auth => null,
      // A signed-in user never goes back to the sign-in step.
      OnboardingV2Step.interests => null,
      OnboardingV2Step.starterPack => state.skipInterests ? null : OnboardingV2Step.interests,
      OnboardingV2Step.aiGenerate => state.skipStarterPack ? OnboardingV2Step.interests : OnboardingV2Step.starterPack,
      OnboardingV2Step.firstWallpaper => OnboardingV2Step.aiGenerate,
    };

    if (prevStep != null) {
      emit(state.copyWith(step: prevStep, navRequest: null));
      return;
    }
    emit(state.copyWith(navRequest: OnboardingV2NavRequest.exitApp));
    emit(state.copyWith(navRequest: null));
  }

  Future<void> _onAiGenerationRequested(_AiGenerationRequested event, Emitter<OnboardingV2State> emit) async {
    emit(state.copyWith(aiData: state.aiData.copyWith(status: AiGenerateStatus.loading), navRequest: null));

    try {
      final record = await _aiRepository.generate(
        prompt: state.aiData.prompt,
        stylePreset: state.aiData.stylePreset,
        qualityTier: AiQualityTier.fast,
        targetSize: event.targetSize,
        chargeMode: AiChargeMode.freeTrial,
        coinsSpent: 0,
      );
      if (!isClosed) {
        add(
          OnboardingV2Event.aiGenerationCompleted(imageUrl: record.imageUrl, thumbnailUrl: record.watermarkedImageUrl),
        );
      }
    } catch (e) {
      logger.e('AI onboarding generation failed: $e', tag: 'OnboardingV2Bloc');
      if (!isClosed) {
        add(const OnboardingV2Event.aiGenerationCompleted(imageUrl: null, thumbnailUrl: null));
      }
    }
  }

  void _onAiGenerationCompleted(_AiGenerationCompleted event, Emitter<OnboardingV2State> emit) {
    final succeeded = event.imageUrl != null && event.imageUrl!.isNotEmpty;
    final updatedAiData = state.aiData.copyWith(
      status: succeeded ? AiGenerateStatus.success : AiGenerateStatus.failure,
      imageUrl: event.imageUrl,
      thumbnailUrl: event.thumbnailUrl,
    );

    if (succeeded) {
      // Pre-populate wallpaperData with the generated image so F4 displays it.
      final generatedVm = OnboardingWallpaperVm(
        fullUrl: event.imageUrl!,
        thumbnailUrl: event.thumbnailUrl ?? event.imageUrl!,
        sourceCategory: state.aiData.stylePreset.label,
      );
      emit(
        state.copyWith(
          aiData: updatedAiData,
          wallpaperData: OnboardingWallpaperData(wallpaper: generatedVm, status: FirstWallpaperStatus.idle),
        ),
      );
    } else {
      emit(state.copyWith(aiData: updatedAiData));
    }
  }

  Future<void> _onAiGenerationStepContinued(_AiGenerationStepContinued event, Emitter<OnboardingV2State> emit) async {
    if (state.step == OnboardingV2Step.firstWallpaper) return;
    final wallpaper = state.wallpaperData.wallpaper;
    if (wallpaper != null && wallpaper.fullUrl.trim().isNotEmpty) {
      unawaited(analytics.track(const OnboardingV2FirstWallpaperShownEvent()));
    }
    emit(state.copyWith(step: OnboardingV2Step.firstWallpaper, navRequest: null));
  }

  /// Picks a style and prompt based on the user's selected interest categories.
  /// Falls back to a random style from the curated pool if no keyword matches.
  OnboardingAiData _promptForInterests(List<String> selectedInterests) {
    AiStylePreset? matchedStyle;

    outer:
    for (final interest in selectedInterests) {
      final lower = interest.toLowerCase();
      for (final entry in OnboardingV2Config.aiInterestStyleMap.entries) {
        if (lower.contains(entry.key)) {
          matchedStyle = entry.value;
          break outer;
        }
      }
    }

    const styles = OnboardingV2Config.aiOnboardingStyles;
    final style = matchedStyle ?? styles[_random.nextInt(styles.length)];
    final prompts = OnboardingV2Config.aiOnboardingPromptPool[style] ?? <String>[];
    final prompt = prompts.isNotEmpty ? prompts[_random.nextInt(prompts.length)] : 'a beautiful wallpaper';
    return OnboardingAiData(prompt: prompt, stylePreset: style, status: AiGenerateStatus.idle);
  }
}
