import 'dart:math' as math;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/complete_onboarding_v2_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/fetch_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/follow_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/services/first_wallpaper_service.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_creator_vm.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_wallpaper_vm.j.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
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
  ) : super(OnboardingV2State.initial()) {
    on<_Started>(_onStarted);
    on<_AuthCompleted>(_onAuthCompleted);
    on<_AuthLoadingChanged>(_onAuthLoadingChanged);
    on<_InterestToggled>(_onInterestToggled);
    on<_InterestsConfirmed>(_onInterestsConfirmed);
    on<_CreatorFollowToggled>(_onCreatorFollowToggled);
    on<_StarterPackConfirmed>(_onStarterPackConfirmed);
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

  // Instantiated directly — same pattern as AiWallpaperTabPage.
  final AiGenerationRepositoryImpl _aiRepository = AiGenerationRepositoryImpl();

  final math.Random _random = math.Random();

  DateTime? _f3EnteredAt;

  Future<void> _onStarted(_Started event, Emitter<OnboardingV2State> emit) async {
    emit(state.copyWith(loadStatus: LoadStatus.loading, failure: null, navRequest: null));
    final settingsLocal = getIt<SettingsLocalDataSource>();
    final catalog = await PersonalizedInterestsCatalog.load(
      remoteConfig: FirebaseRemoteConfig.instance,
      settingsLocal: settingsLocal,
    );
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

    final starterPackResult = await _fetchStarterPackUseCase(const FetchStarterPackParams());
    final List<OnboardingCreatorVm> creatorVms = starterPackResult.fold(
      onSuccess: (entities) {
        final sorted = [...entities]..sort((a, b) => a.rank.compareTo(b.rank));
        final autoSelectedEmails = sorted.take(OnboardingV2Config.minFollows).map((e) => e.email).toSet();
        return sorted
            .map(
              (e) => OnboardingCreatorVm(
                userId: e.userId,
                email: e.email,
                name: e.name,
                photoUrl: e.photoUrl,
                previewUrls: e.previewUrls,
                rank: e.rank,
                isSelected: autoSelectedEmails.contains(e.email),
                bio: e.bio,
                followerCount: e.followerCount,
              ),
            )
            .toList();
      },
      onFailure: (_) => <OnboardingCreatorVm>[],
    );

    final autoSelectedEmails = creatorVms.where((c) => c.isSelected).map((c) => c.email).toList(growable: false);

    final wallpaperVm = await _firstWallpaperService.recommendForOnboarding(<String>[]);

    emit(
      state.copyWith(
        loadStatus: LoadStatus.success,
        interestsData: state.interestsData.copyWith(available: availableCategories, categoryImages: categoryImages),
        starterPackData: OnboardingStarterPackData(creators: creatorVms, selectedEmails: autoSelectedEmails),
        wallpaperData: OnboardingWallpaperData(wallpaper: wallpaperVm, status: FirstWallpaperStatus.idle),
      ),
    );
  }

  Future<void> _onAuthCompleted(_AuthCompleted event, Emitter<OnboardingV2State> emit) async {
    emit(state.copyWith(isAuthLoading: true, navRequest: null));

    final userId = app_state.prismUser.id;
    bool skipInterests = false;
    bool skipStarterPack = false;

    if (!OnboardingV2Config.debugForceOnboarding && userId.isNotEmpty) {
      final statusResult = await _onboardingRepository.fetchUserCompletionStatus(userId: userId);
      statusResult.fold(
        onSuccess: (status) {
          skipInterests = status.hasInterests;
          skipStarterPack = status.hasFollows;
        },
        onFailure: (_) {
          // Fall back to showing all steps on error
        },
      );
    }

    final isPremium = app_state.prismUser.premium;

    if (skipInterests && skipStarterPack) {
      // All steps already done — set skip flags then go to paywall (or complete if premium)
      emit(state.copyWith(isAuthLoading: false, skipInterests: true, skipStarterPack: true, navRequest: null));
      if (isPremium) {
        await _finishOnboarding(emit, didPurchase: true);
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
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null, navRequest: null));

    final selectedInterests = state.interestsData.selected;
    final result = await _saveInterestsUseCase(SaveInterestsParams(interests: selectedInterests));

    if (result.isFailure) {
      emit(state.copyWith(actionStatus: ActionStatus.failure, failure: result.failure));
      return;
    }

    final refreshedWallpaper = await _firstWallpaperService.recommendForOnboarding(selectedInterests);

    final nextStep = state.skipStarterPack ? OnboardingV2Step.aiGenerate : OnboardingV2Step.starterPack;
    emit(
      state.copyWith(
        actionStatus: ActionStatus.success,
        step: nextStep,
        wallpaperData: OnboardingWallpaperData(
          wallpaper: refreshedWallpaper ?? state.wallpaperData.wallpaper,
          status: FirstWallpaperStatus.idle,
        ),
      ),
    );
  }

  void _onCreatorFollowToggled(_CreatorFollowToggled event, Emitter<OnboardingV2State> emit) {
    final current = state.starterPackData.selectedEmails;
    final updated = current.contains(event.creatorEmail)
        ? current.where((e) => e != event.creatorEmail).toList()
        : [...current, event.creatorEmail];

    final updatedCreators = state.starterPackData.creators
        .map((c) => c.copyWith(isSelected: updated.contains(c.email)))
        .toList();

    emit(
      state.copyWith(
        navRequest: null,
        starterPackData: state.starterPackData.copyWith(selectedEmails: updated, creators: updatedCreators),
      ),
    );
  }

  Future<void> _onStarterPackConfirmed(_StarterPackConfirmed event, Emitter<OnboardingV2State> emit) async {
    logger.d(
      'starterPackConfirmed — canContinue=${state.starterPackData.canContinue} isClosed=$isClosed',
      tag: 'OnboardingV2Bloc',
    );
    if (!state.starterPackData.canContinue) {
      logger.d('canContinue=false, aborting', tag: 'OnboardingV2Bloc');
      return;
    }
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null, navRequest: null));
    logger.d('emitted inProgress', tag: 'OnboardingV2Bloc');

    final selectedCreators = state.starterPackData.creators
        .where((c) => c.isSelected)
        .map((c) => OnboardingCreatorFollowParams.creator(userId: c.userId, email: c.email, name: c.name))
        .toList();
    logger.d('selectedCreators count=${selectedCreators.length}', tag: 'OnboardingV2Bloc');

    final result = await _followStarterPackUseCase(FollowStarterPackParams(creators: selectedCreators));
    logger.d(
      'followStarterPackUseCase result isSuccess=${result.isSuccess} isClosed=$isClosed',
      tag: 'OnboardingV2Bloc',
    );

    if (result.isFailure) {
      logger.d('followStarterPackUseCase failure — ${result.failure}', tag: 'OnboardingV2Bloc');
      emit(state.copyWith(actionStatus: ActionStatus.failure, failure: result.failure));
      return;
    }

    if (state.skipInterests) {
      // Interests was skipped → wallpaper must also be skipped → go directly to paywall
      logger.d('starterPackConfirmed — skipInterests=true, going directly to paywall', tag: 'OnboardingV2Bloc');
      emit(state.copyWith(actionStatus: ActionStatus.success, navRequest: null));
      if (app_state.prismUser.premium) {
        await _finishOnboarding(emit, didPurchase: true);
      } else {
        emit(state.copyWith(navRequest: OnboardingV2NavRequest.openPaywall));
      }
    } else {
      logger.d('starterPackConfirmed — emitting step=aiGenerate', tag: 'OnboardingV2Bloc');
      final aiData = _pickRandomAiPrompt(state.interestsData.selected);
      emit(state.copyWith(actionStatus: ActionStatus.success, step: OnboardingV2Step.aiGenerate, aiData: aiData));
      logger.d('emitted aiGenerate step, current state.step=${state.step}', tag: 'OnboardingV2Bloc');
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

    final startMs = DateTime.now().millisecondsSinceEpoch;
    final success = await _firstWallpaperService.performAction(wallpaperVm.fullUrl);
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;

    if (!isClosed) {
      add(OnboardingV2Event.firstWallpaperActionCompleted(success: success, elapsedMs: elapsedMs));
    }
  }

  void _onFirstWallpaperActionCompleted(_FirstWallpaperActionCompleted event, Emitter<OnboardingV2State> emit) {
    emit(
      state.copyWith(
        wallpaperData: state.wallpaperData.copyWith(
          status: event.success ? FirstWallpaperStatus.success : FirstWallpaperStatus.failure,
          elapsedMs: event.elapsedMs,
        ),
      ),
    );
  }

  Future<void> _onFirstWallpaperStepContinued(
    _FirstWallpaperStepContinued event,
    Emitter<OnboardingV2State> emit,
  ) async {
    if (app_state.prismUser.premium) {
      await _finishOnboarding(emit, didPurchase: true);
    } else {
      emit(state.copyWith(navRequest: OnboardingV2NavRequest.openPaywall));
    }
  }

  Future<void> _onPaywallResultReceived(_PaywallResultReceived event, Emitter<OnboardingV2State> emit) async {
    await _finishOnboarding(emit, didPurchase: event.didPurchase);
  }

  Future<void> _finishOnboarding(Emitter<OnboardingV2State> emit, {required bool didPurchase}) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null, navRequest: null));
    final totalMs = _f3EnteredAt != null
        ? DateTime.now().millisecondsSinceEpoch - _f3EnteredAt!.millisecondsSinceEpoch
        : 0;
    final result = await _completeOnboardingUseCase(
      CompleteOnboardingParams(didPurchase: didPurchase, totalElapsedMs: totalMs),
    );
    result.fold(
      onSuccess: (_) => emit(
        state.copyWith(actionStatus: ActionStatus.success, navRequest: OnboardingV2NavRequest.completeOnboarding),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  void _onStepBack(_StepBack event, Emitter<OnboardingV2State> emit) {
    // auth is terminal — no backward navigation
    if (state.step == OnboardingV2Step.auth) return;

    final OnboardingV2Step? prevStep = switch (state.step) {
      OnboardingV2Step.interests => OnboardingV2Step.auth,
      OnboardingV2Step.starterPack => state.skipInterests ? OnboardingV2Step.auth : OnboardingV2Step.interests,
      OnboardingV2Step.aiGenerate => state.skipStarterPack ? OnboardingV2Step.interests : OnboardingV2Step.starterPack,
      OnboardingV2Step.firstWallpaper => OnboardingV2Step.aiGenerate,
      OnboardingV2Step.auth => null,
    };

    if (prevStep != null) {
      emit(state.copyWith(step: prevStep, navRequest: null));
    }
  }

  // ---------------------------------------------------------------------------
  // AI generation step handlers
  // ---------------------------------------------------------------------------

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
        title: 'Your AI wallpaper',
        authorName: 'AI',
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
    _f3EnteredAt = DateTime.now();
    emit(state.copyWith(step: OnboardingV2Step.firstWallpaper, navRequest: null));
  }

  /// Picks a style and prompt based on the user's selected interest categories.
  /// Falls back to a random style from the curated pool if no keyword matches.
  OnboardingAiData _pickRandomAiPrompt(List<String> selectedInterests) {
    AiStylePreset? matchedStyle;

    outer:
    for (final interest in selectedInterests) {
      final lower = interest.toLowerCase();
      for (final entry in OnboardingV2Config.aiInterestStyleMap.entries) {
        if (lower.contains(entry.key) || entry.key.contains(lower)) {
          // Only match single-character keys if they are an exact full match.
          if (entry.key.length == 1 && lower != entry.key) continue;
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
