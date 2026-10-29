import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/startup/firebase_init.dart';
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
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/repositories/taste_quiz_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'onboarding_v2_bloc.j.freezed.dart';
part 'onboarding_v2_event.dart';
part 'onboarding_v2_state.dart';

const Duration _onboardingEnrichmentBudget = Duration(seconds: 3);

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
    this._tasteQuizRepository, {
    @ignoreParam FirebaseRemoteConfig? remoteConfig,
    @ignoreParam AiGenerationRepositoryImpl? aiRepository,
    @ignoreParam Future<String> Function(String)? acquireGeneratedImage,
    @ignoreParam Future<AppLocalizations> Function()? loadLocalizations,
  }) : _aiRepositoryOverride = aiRepository,
       _acquireGeneratedImage = acquireGeneratedImage ?? _acquireGeneratedFile,
       _remoteConfigOverride = remoteConfig,
       _loadLocalizations = loadLocalizations ?? loadDeviceAppLocalizations,
       super(OnboardingV2State.initial()) {
    on<_Started>(_onStarted);
    on<_LoadRetried>(_onLoadRetried);
    on<_AuthCompleted>(_onAuthCompleted);
    on<_GuestBrowseStarted>(_onGuestBrowseStarted);
    on<_AuthLoadingChanged>(_onAuthLoadingChanged);
    on<_InterestToggled>(_onInterestToggled);
    on<_InterestsConfirmed>(_onInterestsConfirmed);
    on<_InterestsSkipped>(_onInterestsSkipped);
    on<_CreatorFollowToggled>(_onCreatorFollowToggled);
    on<_StarterPackConfirmed>(_onStarterPackConfirmed);
    on<_StarterPackReloadRequested>(_onStarterPackReloadRequested);
    on<_StarterPackSkipped>(_onStarterPackSkipped);
    on<_TasteQuizFinished>(_onTasteQuizFinished);
    on<_FirstWallpaperActionRequested>(_onFirstWallpaperActionRequested);
    on<_FirstWallpaperActionCompleted>(_onFirstWallpaperActionCompleted);
    on<_FirstWallpaperStepContinued>(_onFirstWallpaperStepContinued);
    on<_PaywallResultReceived>(_onPaywallResultReceived);
    on<_StepBack>(_onStepBack);
    on<_CompletionRetried>(_onCompletionRetried);
    on<_AiGenerationRequested>(_onAiGenerationRequested);
    on<_AiGenerationCompleted>(_onAiGenerationCompleted);
    on<_AiGenerationStepContinued>(_onAiGenerationStepContinued);
    on<_AiStyleSelected>(_onAiStyleSelected);
  }

  final FetchStarterPackUseCase _fetchStarterPackUseCase;
  final SaveInterestsUseCase _saveInterestsUseCase;
  final FollowStarterPackUseCase _followStarterPackUseCase;
  final CompleteOnboardingV2UseCase _completeOnboardingUseCase;
  final FirstWallpaperService _firstWallpaperService;
  final CategoryFeedRepository _categoryFeedRepository;
  final OnboardingV2Repository _onboardingRepository;
  final SettingsLocalDataSource _settingsLocal;
  final TasteQuizRepository _tasteQuizRepository;
  final FirebaseRemoteConfig? _remoteConfigOverride;
  final Future<AppLocalizations> Function() _loadLocalizations;
  FirebaseRemoteConfig? get _remoteConfig => _remoteConfigOverride ?? FirebaseInit.remoteConfigIfInitialized;
  final AiGenerationRepositoryImpl? _aiRepositoryOverride;
  final Future<String> Function(String) _acquireGeneratedImage;
  static Future<String> _acquireGeneratedFile(String url) async =>
      (await WallpaperService.resolveToLocalFile(url)).path;

  // Built on first use: the default impl touches FirebaseAuth.instance on construction.
  late final AiGenerationRepositoryImpl _aiRepository = _aiRepositoryOverride ?? getIt<AiGenerationRepositoryImpl>();

  final math.Random _random = math.Random();

  static const String _stepAuth = 'auth';
  static const String _stepInterests = 'interests';
  static const String _stepTasteQuiz = 'taste_quiz';
  static const String _stepStarterPack = 'starter_pack';
  static const String _stepAiGenerate = 'ai_generate';
  static const String _stepFirstWallpaper = 'first_wallpaper';

  Stopwatch? _onboardingStopwatch;
  bool _completionInFlight = false;
  bool _completionTracked = false;
  bool? _pendingCompletionDidPurchase;
  int _saveAttemptId = 0;
  int _completionAttemptId = 0;
  bool _paywallHandled = false;

  /// The quiz runs at most once per onboarding, so going back and forward never records the picks twice.
  bool _tasteQuizOffered = false;

  Future<void> _onStarted(_Started event, Emitter<OnboardingV2State> emit) {
    unawaited(analytics.track(const OnboardingStartedEvent()));
    return _loadData(emit);
  }

  Future<void> _onLoadRetried(_LoadRetried event, Emitter<OnboardingV2State> emit) => _loadData(emit);

  Future<void> _loadData(Emitter<OnboardingV2State> emit) async {
    final wallpaperAtStart = state.wallpaperData;
    _onboardingStopwatch ??= Stopwatch()..start();
    emit(state.copyWith(loadStatus: LoadStatus.loading, navRequest: null));
    final catalog = await PersonalizedInterestsCatalog.load(
      remoteConfig: _remoteConfig,
      settingsLocal: _settingsLocal,
    ).timeout(_onboardingEnrichmentBudget, onTimeout: () => const []);
    List<String> availableCategories = catalog.map((e) => e.name).toList(growable: false);
    Map<String, String> categoryImages = <String, String>{for (final entry in catalog) entry.name: entry.imageUrl};
    if (availableCategories.isEmpty) {
      try {
        final categoriesResult = await _categoryFeedRepository.getCategories().timeout(_onboardingEnrichmentBudget);
        categoriesResult.fold(
          onSuccess: (cats) {
            final filtered = cats.where((c) => c.name != OnboardingV2Config.excludedCategory).toList(growable: false);
            availableCategories = filtered.map((c) => c.name).toList(growable: false);
            categoryImages = <String, String>{for (final entry in filtered) entry.name: entry.image};
          },
          onFailure: (_) {},
        );
      } on TimeoutException {
      } catch (error, stackTrace) {
        logger.w('Could not load onboarding categories; using local defaults.', error: error, stackTrace: stackTrace);
      }
    }

    final wallpaperVm = await _recommendFirstWallpaper();

    final latest = state;
    final loadedWallpaper = latest.wallpaperData == wallpaperAtStart
        ? OnboardingWallpaperData(wallpaper: wallpaperVm, status: FirstWallpaperStatus.idle)
        : latest.wallpaperData;

    emit(
      latest.copyWith(
        loadStatus: LoadStatus.success,
        interestsData: latest.interestsData.copyWith(
          available: availableCategories.isEmpty
              ? const <String>['Nature', 'Abstract', 'Architecture', 'Minimal']
              : availableCategories,
          categoryImages: categoryImages,
        ),
        wallpaperData: loadedWallpaper,
      ),
    );
    // A signed-in user who left onboarding part way resumes after sign-in.
    if (app_state.prismUser.loggedIn && state.step == OnboardingV2Step.auth) {
      add(const OnboardingV2Event.authCompleted());
    }
  }

  Future<OnboardingWallpaperVm?> _recommendFirstWallpaper() async {
    try {
      return await _firstWallpaperService.recommendForOnboarding(<String>[]).timeout(_onboardingEnrichmentBudget);
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _onAuthCompleted(_AuthCompleted event, Emitter<OnboardingV2State> emit) async {
    emit(state.copyWith(isAuthLoading: true, navRequest: null));
    _trackStepCompleted(_stepAuth);

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
      final starterPackData = await _fetchStarterPack().timeout(
        _onboardingEnrichmentBudget,
        onTimeout: OnboardingStarterPackData.initial,
      );
      emit(
        state.copyWith(
          isAuthLoading: false,
          step: OnboardingV2Step.starterPack,
          starterPackData: starterPackData,
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
      if (skipStarterPack) return;
      final starterPackData = await _fetchStarterPack();
      if (state.starterPackData.creators.isEmpty) emit(state.copyWith(starterPackData: starterPackData));
    }
  }

  /// The server already has `onboardingV2.completed`: restore the local flag and skip the paywall too.
  Future<void> _skipForReturningUser(Emitter<OnboardingV2State> emit) async {
    _completionTracked = true;
    try {
      await _settingsLocal.set(OnboardingV2Keys.onboardedNew, true);
    } catch (error, stackTrace) {
      logger.w(
        'Could not store the onboarding flag for a returning user.',
        tag: 'OnboardingV2Bloc',
        error: error,
        stackTrace: stackTrace,
      );
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
    if (state.actionStatus == ActionStatus.inProgress) return;
    final current = state.interestsData.selected;
    final updated = current.contains(event.categoryName)
        ? current.where((c) => c != event.categoryName).toList()
        : [...current, event.categoryName];
    emit(state.copyWith(interestsData: state.interestsData.copyWith(selected: updated), navRequest: null));
  }

  void _onGuestBrowseStarted(_GuestBrowseStarted event, Emitter<OnboardingV2State> emit) {
    emit(
      state.copyWith(
        isGuest: true,
        step: OnboardingV2Step.interests,
        actionStatus: ActionStatus.idle,
        isAuthLoading: false,
        navRequest: null,
      ),
    );
  }

  /// A guest has no account to save to, so the picks stay on the device. Signing in later sends them to the server.
  Future<void> _confirmGuestInterests(Emitter<OnboardingV2State> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, navRequest: null));
    final selectedInterests = state.interestsData.selected;
    try {
      await _settingsLocal.set(OnboardingV2Keys.selectedInterests, selectedInterests.join(','));
    } catch (error, stackTrace) {
      logger.w('Could not store the guest interests.', tag: 'OnboardingV2Bloc', error: error, stackTrace: stackTrace);
      emit(state.copyWith(actionStatus: ActionStatus.failure));
      return;
    }
    unawaited(analytics.track(OnboardingV2InterestsCompletedEvent(selectedCount: selectedInterests.length)));
    _trackStepCompleted(_stepInterests);
    await _finishGuest(emit);
  }

  Future<void> _finishGuest(Emitter<OnboardingV2State> emit) async {
    try {
      await _settingsLocal.set(OnboardingV2Keys.onboardedNew, true);
    } catch (error, stackTrace) {
      logger.w(
        'Could not store the onboarding flag for a guest.',
        tag: 'OnboardingV2Bloc',
        error: error,
        stackTrace: stackTrace,
      );
    }
    emit(state.copyWith(actionStatus: ActionStatus.success, navRequest: OnboardingV2NavRequest.openDashboardAsGuest));
  }

  Future<void> _onInterestsConfirmed(_InterestsConfirmed event, Emitter<OnboardingV2State> emit) async {
    if (state.step != OnboardingV2Step.interests ||
        !state.interestsData.canContinue ||
        state.actionStatus == ActionStatus.inProgress) {
      return;
    }
    if (state.isGuest) {
      await _confirmGuestInterests(emit);
      return;
    }
    final attemptId = ++_saveAttemptId;
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, navRequest: null));

    final selectedInterests = state.interestsData.selected;
    // Loads while the interests save, so the quiz rarely adds a wait. It gives up within its own budget.
    final Future<TasteQuizPlan?> quizPlan = _tasteQuizOffered
        ? Future<TasteQuizPlan?>.value()
        : _tasteQuizRepository.loadPlan(selectedInterests);
    final result = await _saveInterestsUseCase(SaveInterestsParams(interests: selectedInterests));
    if (attemptId != _saveAttemptId) return;

    if (result.isFailure) {
      _emitSaveFailure(emit, result.failure!);
      return;
    }

    unawaited(analytics.track(OnboardingV2InterestsCompletedEvent(selectedCount: selectedInterests.length)));
    _trackStepCompleted(_stepInterests);

    OnboardingWallpaperVm? refreshedWallpaper;
    try {
      refreshedWallpaper = await _firstWallpaperService
          .recommendForOnboarding(selectedInterests)
          .timeout(_onboardingEnrichmentBudget, onTimeout: () => null);
    } catch (error, stackTrace) {
      logger.w('Could not refresh the onboarding wallpaper.', error: error, stackTrace: stackTrace);
    }
    if (attemptId != _saveAttemptId) return;
    final plan = await quizPlan;
    if (attemptId != _saveAttemptId || isClosed) return;
    final wallpaperData = OnboardingWallpaperData(
      wallpaper: refreshedWallpaper ?? state.wallpaperData.wallpaper,
      status: FirstWallpaperStatus.idle,
    );

    if (plan != null) {
      _tasteQuizOffered = true;
      emit(
        state.copyWith(
          actionStatus: ActionStatus.success,
          step: OnboardingV2Step.tasteQuiz,
          tasteQuizPlan: plan,
          wallpaperData: wallpaperData,
        ),
      );
      return;
    }
    await _continueAfterInterests(emit, attemptId, wallpaperData: wallpaperData);
  }

  Future<void> _onTasteQuizFinished(_TasteQuizFinished event, Emitter<OnboardingV2State> emit) async {
    if (state.step != OnboardingV2Step.tasteQuiz) return;
    if (event.completed) _trackStepCompleted(_stepTasteQuiz);
    await _continueAfterInterests(emit, ++_saveAttemptId);
  }

  /// The starter pack comes after interests and the quiz, or the AI step when the user already follows creators.
  Future<void> _continueAfterInterests(
    Emitter<OnboardingV2State> emit,
    int attemptId, {
    OnboardingWallpaperData? wallpaperData,
  }) async {
    final nextStep = state.skipStarterPack ? OnboardingV2Step.aiGenerate : OnboardingV2Step.starterPack;
    final aiData = nextStep == OnboardingV2Step.aiGenerate
        ? await _promptForInterests(state.interestsData.selected)
        : state.aiData;
    if (attemptId != _saveAttemptId || isClosed) return;
    emit(
      state.copyWith(
        actionStatus: ActionStatus.success,
        step: nextStep,
        aiData: aiData,
        tasteQuizPlan: null,
        wallpaperData: wallpaperData ?? state.wallpaperData,
      ),
    );
  }

  Future<void> _onInterestsSkipped(_InterestsSkipped event, Emitter<OnboardingV2State> emit) async {
    if (state.step != OnboardingV2Step.interests) return;
    if (state.isGuest) {
      await _finishGuest(emit);
      return;
    }
    final nextStep = state.skipStarterPack ? OnboardingV2Step.aiGenerate : OnboardingV2Step.starterPack;
    final attemptId = ++_saveAttemptId;
    final aiData = nextStep == OnboardingV2Step.aiGenerate ? await _promptForInterests(const <String>[]) : state.aiData;
    if (attemptId != _saveAttemptId || isClosed) return;
    emit(state.copyWith(step: nextStep, actionStatus: ActionStatus.idle, aiData: aiData, navRequest: null));
  }

  void _onCreatorFollowToggled(_CreatorFollowToggled event, Emitter<OnboardingV2State> emit) {
    if (state.actionStatus == ActionStatus.inProgress || state.completionFailed) return;
    final selected = {...state.starterPackData.selectedEmails};
    if (!selected.remove(event.creatorEmail)) selected.add(event.creatorEmail);

    emit(state.copyWith(navRequest: null, starterPackData: state.starterPackData.copyWith(selectedEmails: selected)));
  }

  Future<void> _onStarterPackConfirmed(_StarterPackConfirmed event, Emitter<OnboardingV2State> emit) async {
    if (state.step != OnboardingV2Step.starterPack ||
        !state.starterPackData.canContinue ||
        state.actionStatus == ActionStatus.inProgress) {
      return;
    }
    final attemptId = ++_saveAttemptId;
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, navRequest: null));

    final selectedCreators = state.starterPackData.creators
        .where((c) => state.starterPackData.selectedEmails.contains(c.userId))
        .toList(growable: false);

    final result = await _followStarterPackUseCase(FollowStarterPackParams(creators: selectedCreators));
    if (attemptId != _saveAttemptId) return;

    if (result.isFailure) {
      _emitSaveFailure(emit, result.failure!);
      return;
    }

    unawaited(analytics.track(OnboardingV2StarterPackCompletedEvent(followedCount: selectedCreators.length)));
    _trackStepCompleted(_stepStarterPack);

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
      final attemptId = ++_saveAttemptId;
      final aiData = await _promptForInterests(state.interestsData.selected);
      if (attemptId != _saveAttemptId || isClosed) return;
      emit(state.copyWith(actionStatus: ActionStatus.success, step: OnboardingV2Step.aiGenerate, aiData: aiData));
    }
  }

  /// Loads the starter pack sorted by rank, with the top creators preselected. Call it only after sign-in: the
  /// rules refuse creator profile reads from a signed-out user.
  Future<OnboardingStarterPackData> _fetchStarterPack() async {
    final result = await _fetchStarterPackUseCase(const NoParams());
    final seenEmails = <String>{};
    final List<OnboardingStarterCreatorEntity> creators = result.fold(
      onSuccess: (entities) => [...entities]
        ..sort((a, b) => a.rank.compareTo(b.rank))
        ..removeWhere((creator) => !seenEmails.add(creator.userId)),
      onFailure: (_) => <OnboardingStarterCreatorEntity>[],
    );
    final autoSelectedEmails = creators.take(OnboardingV2Config.minFollows).map((c) => c.userId).toSet();
    return OnboardingStarterPackData(creators: creators, selectedEmails: autoSelectedEmails);
  }

  /// A starter pack with fewer than [OnboardingV2Config.minFollows] creators cannot continue.
  /// The pack comes from Remote Config, so fetch it again before reloading the creators.
  Future<void> _onStarterPackReloadRequested(_StarterPackReloadRequested event, Emitter<OnboardingV2State> emit) async {
    if (state.step != OnboardingV2Step.starterPack || state.actionStatus == ActionStatus.inProgress) return;
    final attemptId = ++_saveAttemptId;
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, navRequest: null));
    try {
      final starterPackData = await _reloadStarterPack(attemptId).timeout(const Duration(seconds: 30));
      if (starterPackData == null || attemptId != _saveAttemptId) return;
      emit(state.copyWith(actionStatus: ActionStatus.idle, starterPackData: starterPackData));
    } on TimeoutException catch (error) {
      logger.w('Starter pack reload timed out; keeping the current creators.', tag: 'OnboardingV2Bloc', error: error);
      if (attemptId != _saveAttemptId) return;
      _saveAttemptId++;
      emit(state.copyWith(actionStatus: ActionStatus.idle));
    }
  }

  Future<OnboardingStarterPackData?> _reloadStarterPack(int attemptId) async {
    try {
      await _remoteConfig?.fetchAndActivate();
    } catch (error) {
      logger.w('Starter pack Remote Config fetch failed; using cached values.', tag: 'OnboardingV2Bloc', error: error);
    }
    if (attemptId != _saveAttemptId || isClosed) return null;
    return _fetchStarterPack();
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
        wallpaperData: state.wallpaperData.copyWith(status: FirstWallpaperStatus.loading, errorCode: null),
      ),
    );

    final actionStopwatch = Stopwatch()..start();
    final result = await _firstWallpaperService.performAction(
      wallpaperVm.fullUrl,
      wallpaperId: wallpaperVm.wallpaperId,
      wallpaperSource: wallpaperVm.wallpaperSource,
    );
    final elapsedMs = actionStopwatch.elapsedMilliseconds;

    if (!isClosed) {
      add(
        OnboardingV2Event.firstWallpaperActionCompleted(
          success: result.success,
          elapsedMs: elapsedMs,
          errorCode: result.errorCode,
          target: result.target,
        ),
      );
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
    if (event.success) _trackStepCompleted(_stepFirstWallpaper);
    emit(
      state.copyWith(
        wallpaperData: state.wallpaperData.copyWith(
          status: event.success ? FirstWallpaperStatus.success : FirstWallpaperStatus.failure,
          errorCode: event.success ? null : event.errorCode,
          target: event.success ? event.target : null,
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

  Future<void> _onCompletionRetried(_CompletionRetried event, Emitter<OnboardingV2State> emit) async {
    final didPurchase = _pendingCompletionDidPurchase;
    if (didPurchase == null || !state.completionFailed || state.actionStatus != ActionStatus.failure) return;
    await _finishOnboarding(emit, didPurchase: didPurchase);
  }

  Future<void> _finishOnboarding(Emitter<OnboardingV2State> emit, {required bool didPurchase}) async {
    if (_completionInFlight || _completionTracked) return;
    _completionInFlight = true;
    _pendingCompletionDidPurchase ??= didPurchase;
    final attemptId = ++_completionAttemptId;
    emit(
      state.copyWith(
        actionStatus: ActionStatus.inProgress,
        completionFailed: false,
        sessionInvalid: false,
        navRequest: null,
      ),
    );
    try {
      // The local flag goes first so a failed server write never traps the user in onboarding.
      await _settingsLocal.set(OnboardingV2Keys.onboardedNew, true);
      final totalMs = _onboardingStopwatch?.elapsedMilliseconds ?? 0;
      final result = await _completeOnboardingUseCase(const NoParams());
      if (attemptId != _completionAttemptId) return;
      result.fold(
        onSuccess: (_) {
          _pendingCompletionDidPurchase = null;
          _trackCompleted(didPurchase: didPurchase, totalMs: totalMs);
          emit(
            state.copyWith(
              actionStatus: ActionStatus.success,
              completionFailed: false,
              navRequest: OnboardingV2NavRequest.completeOnboarding,
            ),
          );
        },
        onFailure: (failure) {
          _pendingCompletionDidPurchase = didPurchase;
          _emitSaveFailure(emit, failure, completionFailed: true);
        },
      );
    } finally {
      if (attemptId == _completionAttemptId) _completionInFlight = false;
    }
  }

  // Firestore codes for a write to the user's own doc that a retry cannot fix.
  static const Set<String> _sessionInvalidCodes = <String>{'permission-denied', 'not-found', 'unauthenticated'};

  void _emitSaveFailure(Emitter<OnboardingV2State> emit, Failure failure, {bool completionFailed = false}) {
    logger.w('Onboarding save failed: ${failure.message}', tag: 'OnboardingV2Bloc');
    // ponytail: the follow batch also writes creator docs, so a deleted creator doc reads as an invalid session.
    emit(
      state.copyWith(
        actionStatus: ActionStatus.failure,
        // A stored session can say loggedIn with no user id: every write then fails before it reaches Firestore.
        sessionInvalid: _sessionInvalidCodes.contains(failure.code) || app_state.prismUser.id.isEmpty,
        completionFailed: completionFailed,
        navRequest: null,
      ),
    );
  }

  void _trackCompleted({required bool didPurchase, required int totalMs}) {
    _completionTracked = true;
    unawaited(analytics.track(OnboardingV2CompletedEvent(didPurchase: didPurchase, totalElapsedMs: totalMs)));
  }

  void _onStepBack(_StepBack event, Emitter<OnboardingV2State> emit) {
    final OnboardingV2Step? prevStep = switch (state.step) {
      OnboardingV2Step.auth => null,
      // A signed-in user never goes back to the sign-in step.
      // A guest came from the sign-in step, so back returns there.
      OnboardingV2Step.interests => state.isGuest ? OnboardingV2Step.auth : null,
      OnboardingV2Step.tasteQuiz => OnboardingV2Step.interests,
      OnboardingV2Step.starterPack => state.skipInterests ? null : OnboardingV2Step.interests,
      OnboardingV2Step.aiGenerate => state.skipStarterPack ? OnboardingV2Step.interests : OnboardingV2Step.starterPack,
      OnboardingV2Step.firstWallpaper => OnboardingV2Step.aiGenerate,
    };

    if (prevStep != null) {
      // A save error belongs to the step that failed, not the one the user goes back to.
      final actionStatus = state.actionStatus == ActionStatus.failure || state.actionStatus == ActionStatus.inProgress
          ? ActionStatus.idle
          : state.actionStatus;
      _pendingCompletionDidPurchase = null;
      _saveAttemptId++;
      _completionAttemptId++;
      _completionInFlight = false;
      emit(
        state.copyWith(
          step: prevStep,
          tasteQuizPlan: null,
          isGuest: state.isGuest && prevStep != OnboardingV2Step.auth,
          actionStatus: actionStatus,
          sessionInvalid: false,
          completionFailed: false,
          navRequest: null,
        ),
      );
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
      final generatedPath = await _acquireGeneratedImage(record.imageUrl);
      if (!isClosed) {
        add(OnboardingV2Event.aiGenerationCompleted(imageUrl: generatedPath, thumbnailUrl: record.watermarkedImageUrl));
      }
    } catch (error, stackTrace) {
      logger.e('AI onboarding generation failed.', tag: 'OnboardingV2Bloc', error: error, stackTrace: stackTrace);
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
        aiStyle: state.aiData.stylePreset,
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
    if (state.aiData.status == AiGenerateStatus.success) _trackStepCompleted(_stepAiGenerate);
    final wallpaper = state.wallpaperData.wallpaper;
    if (wallpaper != null && wallpaper.thumbnailUrl.trim().isNotEmpty) {
      unawaited(analytics.track(const OnboardingV2FirstWallpaperShownEvent()));
    }
    emit(state.copyWith(step: OnboardingV2Step.firstWallpaper, navRequest: null));
  }

  /// A new style takes a prompt written for it. The trial runs once, so the style is fixed from the request on.
  Future<void> _onAiStyleSelected(_AiStyleSelected event, Emitter<OnboardingV2State> emit) async {
    bool locked() =>
        const <AiGenerateStatus>{AiGenerateStatus.loading, AiGenerateStatus.success}.contains(state.aiData.status);
    if (locked()) return;
    unawaited(analytics.track(AiStylePickedEvent(style: event.style.apiValue, source: AiStylePickSource.onboarding)));
    if (event.style == state.aiData.stylePreset) return;
    final OnboardingAiData aiData = await _promptForStyle(event.style);
    if (locked()) return;
    emit(state.copyWith(aiData: aiData, navRequest: null));
  }

  void _trackStepCompleted(String step) => unawaited(analytics.track(OnboardingStepCompletedEvent(step: step)));

  /// Picks a style and prompt based on the user's selected interest categories.
  /// Falls back to a random style from the curated pool if no keyword matches.
  Future<OnboardingAiData> _promptForInterests(List<String> selectedInterests) {
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
    return _promptForStyle(matchedStyle ?? styles[_random.nextInt(styles.length)]);
  }

  Future<OnboardingAiData> _promptForStyle(AiStylePreset style) async {
    final AppLocalizations l10n = await _loadLocalizations();
    final prompts = OnboardingV2Config.aiOnboardingPrompts(l10n, style);
    final prompt = prompts.isNotEmpty
        ? prompts[_random.nextInt(prompts.length)]
        : OnboardingV2Config.aiOnboardingPromptFallback(l10n);
    return OnboardingAiData(prompt: prompt, stylePreset: style, status: AiGenerateStatus.idle);
  }
}
