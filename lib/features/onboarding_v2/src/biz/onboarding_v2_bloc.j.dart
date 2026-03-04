import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/complete_onboarding_v2_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/fetch_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/follow_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/services/first_wallpaper_service.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_creator_vm.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_wallpaper_vm.j.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

part 'onboarding_v2_event.dart';
part 'onboarding_v2_state.dart';
part 'onboarding_v2_bloc.j.freezed.dart';

@injectable
class OnboardingV2Bloc extends Bloc<OnboardingV2Event, OnboardingV2State> {
  OnboardingV2Bloc(
    this._fetchStarterPackUseCase,
    this._saveInterestsUseCase,
    this._followStarterPackUseCase,
    this._completeOnboardingUseCase,
    this._firstWallpaperService,
    this._categoryFeedRepository,
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
    on<_PaywallTimerTicked>(_onPaywallTimerTicked);
    on<_PaywallPrimaryTapped>(_onPaywallPrimaryTapped);
    on<_PaywallContinueFreeTapped>(_onPaywallContinueFreeTapped);
    on<_PaywallResultReceived>(_onPaywallResultReceived);
  }

  final FetchStarterPackUseCase _fetchStarterPackUseCase;
  final SaveInterestsUseCase _saveInterestsUseCase;
  final FollowStarterPackUseCase _followStarterPackUseCase;
  final CompleteOnboardingV2UseCase _completeOnboardingUseCase;
  final FirstWallpaperService _firstWallpaperService;
  final CategoryFeedRepository _categoryFeedRepository;

  Timer? _paywallTimer;
  DateTime? _f3EnteredAt;

  Future<void> _onStarted(_Started event, Emitter<OnboardingV2State> emit) async {
    emit(state.copyWith(loadStatus: LoadStatus.loading, failure: null, navRequest: null));

    final categoriesResult = await _categoryFeedRepository.getCategories();
    final List<CategoryEntity> filteredCategories = categoriesResult.fold(
      onSuccess: (cats) => cats.where((c) => c.name != OnboardingV2Config.excludedCategory).toList(growable: false),
      onFailure: (_) => <CategoryEntity>[],
    );

    final availableCategories = filteredCategories.map((c) => c.name).toList(growable: false);
    final categoryImages = <String, String>{for (final c in filteredCategories) c.name: c.image};

    final starterPackResult = await _fetchStarterPackUseCase(const FetchStarterPackParams());
    final List<OnboardingCreatorVm> creatorVms = starterPackResult.fold(
      onSuccess: (entities) {
        final sorted = [...entities]..sort((a, b) => a.rank.compareTo(b.rank));
        final preselected = sorted.take(OnboardingV2Config.preselectedCreatorsCount).map((e) => e.email).toList();
        return sorted
            .map(
              (e) => OnboardingCreatorVm(
                userId: e.userId,
                email: e.email,
                name: e.name,
                photoUrl: e.photoUrl,
                previewUrls: e.previewUrls,
                rank: e.rank,
                isSelected: preselected.contains(e.email),
                bio: e.bio,
                followerCount: e.followerCount,
              ),
            )
            .toList();
      },
      onFailure: (_) => <OnboardingCreatorVm>[],
    );

    final preselectedEmails = creatorVms.where((c) => c.isSelected).map((c) => c.email).toList();
    final wallpaperVm = await _firstWallpaperService.recommendForOnboarding(<String>[]);

    emit(
      state.copyWith(
        loadStatus: LoadStatus.success,
        interestsData: state.interestsData.copyWith(available: availableCategories, categoryImages: categoryImages),
        starterPackData: OnboardingStarterPackData(creators: creatorVms, selectedEmails: preselectedEmails),
        wallpaperData: OnboardingWallpaperData(wallpaper: wallpaperVm, status: FirstWallpaperStatus.idle),
      ),
    );
  }

  void _onAuthCompleted(_AuthCompleted event, Emitter<OnboardingV2State> emit) {
    emit(state.copyWith(isAuthLoading: false, step: OnboardingV2Step.interests, navRequest: null));
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

    emit(
      state.copyWith(
        actionStatus: ActionStatus.success,
        step: OnboardingV2Step.starterPack,
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

    result.fold(
      onSuccess: (_) {
        logger.d('fold onSuccess — emitting step=firstWallpaper', tag: 'OnboardingV2Bloc');
        _f3EnteredAt = DateTime.now();
        emit(state.copyWith(actionStatus: ActionStatus.success, step: OnboardingV2Step.firstWallpaper));
        logger.d('emitted firstWallpaper step, current state.step=${state.step}', tag: 'OnboardingV2Bloc');
      },
      onFailure: (failure) {
        logger.d('fold onFailure — $failure', tag: 'OnboardingV2Bloc');
        emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure));
      },
    );
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

    add(OnboardingV2Event.firstWallpaperActionCompleted(success: success, elapsedMs: elapsedMs));
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

  void _onFirstWallpaperStepContinued(_FirstWallpaperStepContinued event, Emitter<OnboardingV2State> emit) {
    _startPaywallTimer();
    emit(
      state.copyWith(
        step: OnboardingV2Step.paywall,
        paywallData: OnboardingPaywallData.initial(),
        navRequest: OnboardingV2NavRequest.openPaywall,
      ),
    );
  }

  void _startPaywallTimer() {
    _paywallTimer?.cancel();
    _paywallTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) {
        add(const OnboardingV2Event.paywallTimerTicked());
      }
    });
  }

  void _onPaywallTimerTicked(_PaywallTimerTicked event, Emitter<OnboardingV2State> emit) {
    final remaining = state.paywallData.timerRemainingSeconds - 1;
    if (remaining <= 0) {
      _paywallTimer?.cancel();
      emit(
        state.copyWith(
          navRequest: null,
          paywallData: state.paywallData.copyWith(continueUnlocked: true, timerRemainingSeconds: 0),
        ),
      );
    } else {
      emit(state.copyWith(navRequest: null, paywallData: state.paywallData.copyWith(timerRemainingSeconds: remaining)));
    }
  }

  void _onPaywallPrimaryTapped(_PaywallPrimaryTapped event, Emitter<OnboardingV2State> emit) {
    emit(state.copyWith(navRequest: OnboardingV2NavRequest.openPaywall));
  }

  Future<void> _onPaywallContinueFreeTapped(_PaywallContinueFreeTapped event, Emitter<OnboardingV2State> emit) async {
    await _finishOnboarding(emit, didPurchase: false);
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

  @override
  Future<void> close() async {
    _paywallTimer?.cancel();
    return super.close();
  }
}
