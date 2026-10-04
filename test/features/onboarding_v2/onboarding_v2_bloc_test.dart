import 'dart:async';

import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/complete_onboarding_v2_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/fetch_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/follow_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/services/first_wallpaper_service.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_wallpaper_vm.j.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockFetchStarterPackUseCase extends Mock implements FetchStarterPackUseCase {}

class _MockSaveInterestsUseCase extends Mock implements SaveInterestsUseCase {}

class _MockFollowStarterPackUseCase extends Mock implements FollowStarterPackUseCase {}

class _MockCompleteOnboardingV2UseCase extends Mock implements CompleteOnboardingV2UseCase {}

class _MockFirstWallpaperService extends Mock implements FirstWallpaperService {}

class _MockCategoryFeedRepository extends Mock implements CategoryFeedRepository {}

class _MockOnboardingV2Repository extends Mock implements OnboardingV2Repository {}

class _MockSettingsLocalDataSource extends Mock implements SettingsLocalDataSource {}

class _MockFirebaseRemoteConfig extends Mock implements FirebaseRemoteConfig {}

class _MockAiGenerationRepository extends Mock implements AiGenerationRepositoryImpl {}

PrismUsersV2 _user({required String id, required bool loggedIn, bool premium = false}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return PrismUsersV2(
    username: '',
    email: 'resume@example.com',
    id: id,
    createdAt: now,
    premium: premium,
    lastLoginAt: now,
    links: const <String, String>{},
    followers: const <String>[],
    following: const <String>[],
    profilePhoto: '',
    bio: '',
    loggedIn: loggedIn,
    badges: <Badge>[],
    subPrisms: const <String>[],
    coins: 0,
    transactions: <PrismTransaction>[],
    name: '',
    coverPhoto: '',
  );
}

OnboardingStarterCreatorEntity _creator(int i) => OnboardingStarterCreatorEntity(
  userId: 'creator-$i',
  email: 'creator-$i@example.com',
  name: 'Creator $i',
  photoUrl: '',
  previewUrls: const <String>[],
  rank: i,
  followerCount: 0,
);

AiGenerationRecord _aiRecord() => AiGenerationRecord(
  id: 'gen-1',
  userId: 'u1',
  createdAt: DateTime.utc(2026),
  prompt: 'prompt',
  stylePreset: AiStylePreset.nature,
  qualityTier: AiQualityTier.fast,
  provider: 'p',
  model: 'm',
  seed: 1,
  width: 1,
  height: 1,
  imageUrl: 'https://example.com/full.jpg',
  watermarkedImageUrl: 'https://example.com/thumb.jpg',
  chargeMode: AiChargeMode.freeTrial,
  coinsSpent: 0,
  status: 'done',
);

void main() {
  late _MockFetchStarterPackUseCase fetchStarterPackUseCase;
  late _MockSaveInterestsUseCase saveInterestsUseCase;
  late _MockFollowStarterPackUseCase followStarterPackUseCase;
  late _MockCompleteOnboardingV2UseCase completeOnboardingUseCase;
  late _MockFirstWallpaperService firstWallpaperService;
  late _MockCategoryFeedRepository categoryFeedRepository;
  late _MockOnboardingV2Repository onboardingRepository;
  late _MockSettingsLocalDataSource settingsLocalDataSource;
  late _MockFirebaseRemoteConfig remoteConfig;
  late _MockAiGenerationRepository aiRepository;
  late FakeAppAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(const <String>[]);
    registerFallbackValue(const SaveInterestsParams(interests: <String>[]));
    registerFallbackValue(const FollowStarterPackParams(creators: <OnboardingStarterCreatorEntity>[]));
    registerFallbackValue(const NoParams());
    registerFallbackValue(AiStylePreset.nature);
    registerFallbackValue(AiQualityTier.fast);
    registerFallbackValue(AiChargeMode.freeTrial);
  });

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    fetchStarterPackUseCase = _MockFetchStarterPackUseCase();
    saveInterestsUseCase = _MockSaveInterestsUseCase();
    followStarterPackUseCase = _MockFollowStarterPackUseCase();
    completeOnboardingUseCase = _MockCompleteOnboardingV2UseCase();
    firstWallpaperService = _MockFirstWallpaperService();
    categoryFeedRepository = _MockCategoryFeedRepository();
    onboardingRepository = _MockOnboardingV2Repository();
    settingsLocalDataSource = _MockSettingsLocalDataSource();
    remoteConfig = _MockFirebaseRemoteConfig();
    aiRepository = _MockAiGenerationRepository();

    // Empty remote config and cache make PersonalizedInterestsCatalog fall back to the built-in
    // catalog, which is non-empty, so _onStarted never calls categoryFeedRepository.getCategories().
    when(() => remoteConfig.getString(any())).thenReturn('');
    when(
      () => settingsLocalDataSource.get<String>(app_constants.personalizedInterestsLocalCacheKey, defaultValue: ''),
    ).thenReturn('');
    when(
      () => fetchStarterPackUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.success(<OnboardingStarterCreatorEntity>[]));
    when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer((_) async => null);
    when(
      () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
    ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: false, hasFollows: false)));
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  OnboardingV2Bloc buildBloc() => OnboardingV2Bloc(
    fetchStarterPackUseCase,
    saveInterestsUseCase,
    followStarterPackUseCase,
    completeOnboardingUseCase,
    firstWallpaperService,
    categoryFeedRepository,
    onboardingRepository,
    settingsLocalDataSource,
    remoteConfig,
    aiRepository: aiRepository,
  );

  Iterable<String> trackedNames() => analytics.events.map((event) => event.eventName);

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'a signed-in user who left onboarding mid-flow resumes past the auth step',
    setUp: () => app_state.prismUser = _user(id: 'resume-user', loggedIn: true),
    build: buildBloc,
    act: (bloc) => bloc.add(const OnboardingV2Event.started()),
    verify: (bloc) {
      // _onAuthCompleted moves a user with no saved interests/follows to the interests step.
      expect(bloc.state.step, OnboardingV2Step.interests);
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'a logged-out user stays on the auth step after started',
    setUp: () => app_state.prismUser = _user(id: 'guest', loggedIn: false),
    build: buildBloc,
    act: (bloc) => bloc.add(const OnboardingV2Event.started()),
    verify: (bloc) {
      expect(bloc.state.step, OnboardingV2Step.auth);
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'the first creators by rank start selected and toggling changes only the selection',
    setUp: () {
      when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
        (_) async => Result.success(List<OnboardingStarterCreatorEntity>.generate(5, (i) => _creator(4 - i))),
      );
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
      bloc.add(const OnboardingV2Event.creatorFollowToggled('creator-0@example.com'));
      bloc.add(const OnboardingV2Event.creatorFollowToggled('creator-4@example.com'));
    },
    verify: (bloc) {
      final pack = bloc.state.starterPackData;
      expect(pack.creators.map((c) => c.rank), <int>[0, 1, 2, 3, 4]);
      expect(pack.selectedEmails, <String>{'creator-1@example.com', 'creator-2@example.com', 'creator-4@example.com'});
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'records selected interests only after saving succeeds',
    setUp: () {
      when(() => saveInterestsUseCase(any())).thenAnswer((_) async => Result.success(null));
    },
    build: buildBloc,
    act: (bloc) async {
      app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
      bloc.add(const OnboardingV2Event.interestToggled('Nature'));
      bloc.add(const OnboardingV2Event.interestToggled('Anime'));
      bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.interestsConfirmed());
    },
    verify: (_) {
      expect(trackedNames(), contains('onboarding_v2_interests_completed'));
      expect(
        analytics.events.singleWhere((e) => e.eventName == 'onboarding_v2_interests_completed').toWireParameters(),
        <String, Object?>{'selected_count': 3},
      );
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'does not record interests when saving fails',
    setUp: () {
      when(
        () => saveInterestsUseCase(any()),
      ).thenAnswer((_) async => Result.error(const ServerFailure('write failed')));
    },
    build: buildBloc,
    act: (bloc) async {
      app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
      bloc.add(const OnboardingV2Event.interestToggled('Nature'));
      bloc.add(const OnboardingV2Event.interestToggled('Anime'));
      bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.interestsConfirmed());
    },
    verify: (_) => expect(analytics.events, isEmpty),
  );

  group('save failures', () {
    late Completer<Result<void>> pendingInterestsResult;
    late Completer<Result<void>> pendingStarterPackResult;
    late Completer<OnboardingWallpaperVm?> pendingRecommendation;
    late Completer<void> recommendationStarted;

    Future<void> confirmInterests(OnboardingV2Bloc bloc) async {
      app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
      bloc.add(const OnboardingV2Event.interestToggled('Nature'));
      bloc.add(const OnboardingV2Event.interestToggled('Anime'));
      bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.interestsConfirmed());
    }

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'ignores save confirmations that do not match the current step',
      setUp: () => when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
        (_) async =>
            Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
      ),
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
        bloc.add(const OnboardingV2Event.interestToggled('Nature'));
        bloc.add(const OnboardingV2Event.interestToggled('Anime'));
        bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OnboardingV2Event.interestsConfirmed());
        bloc.add(const OnboardingV2Event.starterPackConfirmed());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.auth);
        expect(bloc.state.actionStatus, ActionStatus.idle);
        verifyNever(() => saveInterestsUseCase(any()));
        verifyNever(() => followStarterPackUseCase(any()));
      },
    );

    for (final code in <String?>[null, 'unavailable']) {
      blocTest<OnboardingV2Bloc, OnboardingV2State>(
        'an interests save failure with a user id remains retryable${code == null ? ' for a generic error' : ' for $code'}',
        setUp: () => when(
          () => saveInterestsUseCase(any()),
        ).thenAnswer((_) async => Result.error(ServerFailure('offline', code: code))),
        build: buildBloc,
        act: confirmInterests,
        verify: (bloc) {
          expect(bloc.state.step, OnboardingV2Step.interests);
          expect(bloc.state.actionStatus, ActionStatus.failure);
          expect(bloc.state.sessionInvalid, isFalse);
          expect(bloc.state.interestsData.selected, <String>['Nature', 'Anime', 'Minimal']);
          expect(bloc.state.navRequest, isNull);
          expect(trackedNames(), isEmpty);
        },
      );
    }

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a signed-in session with no user id marks the session invalid, whatever the error',
      setUp: () {
        app_state.prismUser = _user(id: '', loggedIn: true);
        when(
          () => saveInterestsUseCase(any()),
        ).thenAnswer((_) async => Result.error(const ServerFailure('A document path must be a non-empty string')));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestToggled('Nature'));
        bloc.add(const OnboardingV2Event.interestToggled('Anime'));
        bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OnboardingV2Event.interestsConfirmed());
      },
      verify: (bloc) {
        expect(bloc.state.actionStatus, ActionStatus.failure);
        expect(bloc.state.sessionInvalid, isTrue);
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a starter-pack save failure with no user id marks the session invalid',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        when(
          () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
        ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: true, hasFollows: false)));
        when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
          (_) async =>
              Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
        );
        when(
          () => followStarterPackUseCase(any()),
        ).thenAnswer((_) async => Result.error(const ServerFailure('A document path must be a non-empty string')));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
        app_state.prismUser = _user(id: '', loggedIn: true);
        bloc.add(const OnboardingV2Event.starterPackConfirmed());
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.starterPack);
        expect(bloc.state.actionStatus, ActionStatus.failure);
        expect(bloc.state.sessionInvalid, isTrue);
        expect(bloc.state.completionFailed, isFalse);
        expect(bloc.state.navRequest, isNull);
        expect(bloc.state.starterPackData.selectedEmails, <String>{
          for (var i = 0; i < OnboardingV2Config.minFollows; i++) 'creator-$i@example.com',
        });
        expect(trackedNames(), isNot(contains('onboarding_v2_starter_pack_completed')));
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a generic starter-pack save failure with a user id remains retryable',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        when(
          () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
        ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: true, hasFollows: false)));
        when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
          (_) async =>
              Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
        );
        when(
          () => followStarterPackUseCase(any()),
        ).thenAnswer((_) async => Result.error(const ServerFailure('offline')));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
        bloc.add(const OnboardingV2Event.starterPackConfirmed());
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.starterPack);
        expect(bloc.state.actionStatus, ActionStatus.failure);
        expect(bloc.state.sessionInvalid, isFalse);
        expect(bloc.state.completionFailed, isFalse);
        expect(bloc.state.navRequest, isNull);
        expect(bloc.state.starterPackData.selectedEmails, <String>{
          for (var i = 0; i < OnboardingV2Config.minFollows; i++) 'creator-$i@example.com',
        });
        expect(trackedNames(), isNot(contains('onboarding_v2_starter_pack_completed')));
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a completion failure with no user id marks the session invalid without tracking completion',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        when(
          () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
        ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: false, hasFollows: true)));
        when(() => saveInterestsUseCase(any())).thenAnswer((_) async => Result.success(null));
        when(
          () => completeOnboardingUseCase(any()),
        ).thenAnswer((_) async => Result.error(const ServerFailure('A document path must be a non-empty string')));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestToggled('Nature'));
        bloc.add(const OnboardingV2Event.interestToggled('Anime'));
        bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OnboardingV2Event.interestsConfirmed());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.aiGenerate);
        bloc.add(const OnboardingV2Event.aiGenerationStepContinued());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.firstWallpaper);
        app_state.prismUser = _user(id: '', loggedIn: true);
        bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: true));
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.firstWallpaper);
        expect(bloc.state.actionStatus, ActionStatus.failure);
        expect(bloc.state.completionFailed, isTrue);
        expect(bloc.state.sessionInvalid, isTrue);
        expect(bloc.state.navRequest, isNull);
        expect(bloc.state.interestsData.selected, <String>['Nature', 'Anime', 'Minimal']);
        expect(trackedNames(), isNot(contains('onboarding_v2_completed')));
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'ignores duplicate interest submissions while the first save is pending',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        pendingInterestsResult = Completer<Result<void>>();
        when(() => saveInterestsUseCase(any())).thenAnswer((_) => pendingInterestsResult.future);
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestToggled('Nature'));
        bloc.add(const OnboardingV2Event.interestToggled('Anime'));
        bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OnboardingV2Event.interestsConfirmed());
        await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.inProgress);
        bloc.add(const OnboardingV2Event.interestsConfirmed());
        await Future<void>.delayed(Duration.zero);
        verify(() => saveInterestsUseCase(any())).called(1);
        pendingInterestsResult.complete(Result.success(null));
        await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.success);
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.starterPack);
        expect(bloc.state.actionStatus, ActionStatus.success);
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'keeps interest selection aligned with the pending save snapshot',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        pendingInterestsResult = Completer<Result<void>>();
        when(() => saveInterestsUseCase(any())).thenAnswer((_) => pendingInterestsResult.future);
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestToggled('Nature'));
        bloc.add(const OnboardingV2Event.interestToggled('Anime'));
        bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
        await Future<void>.delayed(Duration.zero);
        final submittedInterests = List<String>.of(bloc.state.interestsData.selected);
        bloc.add(const OnboardingV2Event.interestsConfirmed());
        await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.inProgress);
        bloc.add(const OnboardingV2Event.interestToggled('Nature'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.interestsData.selected, submittedInterests);
        final saveParams = verify(() => saveInterestsUseCase(captureAny())).captured.single as SaveInterestsParams;
        expect(saveParams.interests, submittedInterests);
        pendingInterestsResult.complete(Result.success(null));
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
      },
      verify: (bloc) {
        expect(bloc.state.interestsData.selected, <String>['Nature', 'Anime', 'Minimal']);
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'ignores duplicate starter-pack submissions while the first save is pending',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        when(
          () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
        ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: true, hasFollows: false)));
        pendingStarterPackResult = Completer<Result<void>>();
        when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
          (_) async =>
              Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
        );
        when(() => followStarterPackUseCase(any())).thenAnswer((_) => pendingStarterPackResult.future);
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
        bloc.add(const OnboardingV2Event.starterPackConfirmed());
        await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.inProgress);
        bloc.add(const OnboardingV2Event.starterPackConfirmed());
        await Future<void>.delayed(Duration.zero);
        verify(() => followStarterPackUseCase(any())).called(1);
        pendingStarterPackResult.complete(Result.success(null));
        await bloc.stream.firstWhere((s) => s.navRequest == OnboardingV2NavRequest.openPaywall);
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.starterPack);
        expect(bloc.state.actionStatus, ActionStatus.success);
        expect(bloc.state.navRequest, OnboardingV2NavRequest.openPaywall);
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'backing out and returning while an interests save is pending ignores its stale failure',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        pendingInterestsResult = Completer<Result<void>>();
        when(() => saveInterestsUseCase(any())).thenAnswer((_) => pendingInterestsResult.future);
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestToggled('Nature'));
        bloc.add(const OnboardingV2Event.interestToggled('Anime'));
        bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OnboardingV2Event.interestsConfirmed());
        await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.inProgress);
        bloc.add(const OnboardingV2Event.stepBack());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.auth);
        bloc.add(const OnboardingV2Event.authCompleted());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        pendingInterestsResult.complete(Result.error(const ServerFailure('offline')));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.interests);
        expect(bloc.state.actionStatus, ActionStatus.idle);
        expect(bloc.state.sessionInvalid, isFalse);
      },
      wait: const Duration(milliseconds: 10),
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'backing out during wallpaper refresh does not advance the step after returning',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        var recommendationCalls = 0;
        recommendationStarted = Completer<void>();
        pendingRecommendation = Completer<OnboardingWallpaperVm?>();
        when(() => saveInterestsUseCase(any())).thenAnswer((_) async => Result.success(null));
        when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer((_) {
          recommendationCalls++;
          if (recommendationCalls == 2) {
            recommendationStarted.complete();
            return pendingRecommendation.future;
          }
          return Future<OnboardingWallpaperVm?>.value();
        });
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestToggled('Nature'));
        bloc.add(const OnboardingV2Event.interestToggled('Anime'));
        bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OnboardingV2Event.interestsConfirmed());
        await recommendationStarted.future;
        bloc.add(const OnboardingV2Event.stepBack());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.auth);
        bloc.add(const OnboardingV2Event.authCompleted());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        pendingRecommendation.complete(null);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.interests);
        expect(bloc.state.actionStatus, ActionStatus.idle);
      },
    );

    for (final code in <String>['permission-denied', 'not-found', 'unauthenticated']) {
      blocTest<OnboardingV2Bloc, OnboardingV2State>(
        '$code on interests marks the session invalid',
        setUp: () => when(
          () => saveInterestsUseCase(any()),
        ).thenAnswer((_) async => Result.error(ServerFailure('refused', code: code))),
        build: buildBloc,
        act: confirmInterests,
        verify: (bloc) {
          expect(bloc.state.actionStatus, ActionStatus.failure);
          expect(bloc.state.sessionInvalid, isTrue);
        },
      );
    }

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'permission-denied on the starter pack marks the session invalid, and going back clears the failure',
      setUp: () {
        when(
          () => followStarterPackUseCase(any()),
        ).thenAnswer((_) async => Result.error(const ServerFailure('refused', code: 'permission-denied')));
        when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
          (_) async =>
              Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
        );
        when(() => saveInterestsUseCase(any())).thenAnswer((_) async => Result.success(null));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
        await confirmInterests(bloc);
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
        bloc.add(const OnboardingV2Event.starterPackConfirmed());
        final failed = await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.failure);
        expect(failed.step, OnboardingV2Step.starterPack);
        expect(failed.sessionInvalid, isTrue);
        bloc.add(const OnboardingV2Event.stepBack());
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.interests);
        expect(bloc.state.actionStatus, ActionStatus.idle);
        expect(bloc.state.sessionInvalid, isFalse);
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'retries completion after a successful skipped-interests follow without following twice',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true, premium: true);
        when(
          () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
        ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: true, hasFollows: false)));
        when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
          (_) async =>
              Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
        );
        when(() => followStarterPackUseCase(any())).thenAnswer((_) async => Result.success(null));
        when(
          () => completeOnboardingUseCase(any()),
        ).thenAnswer((_) async => Result.error(const ServerFailure('offline')));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
        bloc.add(const OnboardingV2Event.starterPackConfirmed());
        final failed = await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.failure);
        expect(failed.completionFailed, isTrue);
        final persistedSelection = Set<String>.of(failed.starterPackData.selectedEmails);
        bloc.add(OnboardingV2Event.creatorFollowToggled(persistedSelection.first));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.starterPackData.selectedEmails, persistedSelection);
        when(() => completeOnboardingUseCase(any())).thenAnswer((_) async => Result.success(null));
        bloc.add(const OnboardingV2Event.completionRetried());
        await bloc.stream.firstWhere((s) => s.navRequest == OnboardingV2NavRequest.completeOnboarding);
      },
      verify: (bloc) {
        final followVerification = verify(() => followStarterPackUseCase(captureAny()));
        followVerification.called(1);
        final followed = followVerification.captured.single as FollowStarterPackParams;
        expect(followed.creators.map((creator) => creator.email).toSet(), bloc.state.starterPackData.selectedEmails);
        verify(() => completeOnboardingUseCase(any())).called(2);
        expect(bloc.state.completionFailed, isFalse);
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a completion retry preserves the purchase result for analytics',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        when(
          () => completeOnboardingUseCase(any()),
        ).thenAnswer((_) async => Result.error(const ServerFailure('offline')));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: true));
        final failed = await bloc.stream.firstWhere((s) => s.completionFailed);
        expect(failed.actionStatus, ActionStatus.failure);
        expect(failed.sessionInvalid, isFalse);
        expect(failed.navRequest, isNull);
        expect(trackedNames(), isNot(contains('onboarding_v2_completed')));
        when(() => completeOnboardingUseCase(any())).thenAnswer((_) async => Result.success(null));
        bloc.add(const OnboardingV2Event.completionRetried());
        await bloc.stream.firstWhere((s) => s.navRequest == OnboardingV2NavRequest.completeOnboarding);
      },
      verify: (_) {
        expect(
          analytics.events.singleWhere((event) => event.eventName == 'onboarding_v2_completed').toWireParameters(),
          containsPair('did_purchase', 1),
        );
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a completion that fails after step-back cannot clear a newer completion in flight',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        when(
          () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
        ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: false, hasFollows: true)));
        when(() => saveInterestsUseCase(any())).thenAnswer((_) async => Result.success(null));
      },
      build: buildBloc,
      act: (bloc) async {
        final oldCompletion = Completer<Result<void>>();
        final newCompletion = Completer<Result<void>>();
        var completionCalls = 0;
        when(() => completeOnboardingUseCase(any())).thenAnswer((_) {
          completionCalls++;
          return completionCalls == 1 ? oldCompletion.future : newCompletion.future;
        });
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestToggled('Nature'));
        bloc.add(const OnboardingV2Event.interestToggled('Anime'));
        bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OnboardingV2Event.interestsConfirmed());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.aiGenerate);
        bloc.add(const OnboardingV2Event.aiGenerationStepContinued());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.firstWallpaper);
        bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: true));
        await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.inProgress);
        bloc.add(const OnboardingV2Event.stepBack());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.aiGenerate);
        bloc.add(const OnboardingV2Event.aiGenerationStepContinued());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.firstWallpaper);
        bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: false));
        await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.inProgress);
        oldCompletion.complete(Result.error(const ServerFailure('old request failed')));
        await Future<void>.delayed(Duration.zero);
        expect(completionCalls, 2);
        expect(bloc.state.actionStatus, ActionStatus.inProgress);
        bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: false));
        await Future<void>.delayed(Duration.zero);
        expect(completionCalls, 2);
        newCompletion.complete(Result.success(null));
        await bloc.stream.firstWhere((s) => s.navRequest == OnboardingV2NavRequest.completeOnboarding);
      },
      verify: (bloc) {
        expect(bloc.state.actionStatus, ActionStatus.success);
        expect(
          analytics.events.singleWhere((event) => event.eventName == 'onboarding_v2_completed').toWireParameters(),
          containsPair('did_purchase', 0),
        );
      },
    );
  });

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'records starter-pack follows after the follow write succeeds',
    setUp: () {
      app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
      when(
        () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
      ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: true, hasFollows: false)));
      when(() => followStarterPackUseCase(any())).thenAnswer((_) async => Result.success(null));
      when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
        (_) async =>
            Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
      );
    },
    build: buildBloc,
    act: (bloc) async {
      app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
      bloc.add(const OnboardingV2Event.starterPackConfirmed());
    },
    verify: (_) {
      final event = analytics.events.singleWhere((e) => e.eventName == 'onboarding_v2_starter_pack_completed');
      expect(event.toWireParameters(), <String, Object?>{'followed_count': OnboardingV2Config.minFollows});
      final followed = verify(() => followStarterPackUseCase(captureAny())).captured.single as FollowStarterPackParams;
      expect(followed.creators.map((c) => c.email), <String>[
        for (var i = 0; i < OnboardingV2Config.minFollows; i++) 'creator-$i@example.com',
      ]);
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'reloading a short starter pack refreshes Remote Config and preselects the new creators',
    setUp: () {
      app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
      when(
        () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
      ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: true, hasFollows: false)));
      when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
      var calls = 0;
      when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
        (_) async => Result.success(
          List<OnboardingStarterCreatorEntity>.generate(calls++ == 0 ? 1 : OnboardingV2Config.minFollows + 1, _creator),
        ),
      );
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.started());
      final short = await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
      expect(short.starterPackData.canContinue, isFalse);
      bloc.add(const OnboardingV2Event.starterPackReloadRequested());
      await bloc.stream.firstWhere((s) => s.starterPackData.creators.length > 1);
    },
    verify: (bloc) {
      verify(() => remoteConfig.fetchAndActivate()).called(1);
      expect(bloc.state.actionStatus, ActionStatus.idle);
      expect(bloc.state.starterPackData.canContinue, isTrue);
      expect(bloc.state.starterPackData.selectedEmails, <String>{
        for (var i = 0; i < OnboardingV2Config.minFollows; i++) 'creator-$i@example.com',
      });
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'a failed Remote Config fetch still reloads the starter pack',
    setUp: () {
      app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
      when(
        () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
      ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: true, hasFollows: false)));
      when(() => remoteConfig.fetchAndActivate()).thenThrow(Exception('throttled'));
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
      bloc.add(const OnboardingV2Event.starterPackReloadRequested());
      await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.idle);
    },
    verify: (bloc) {
      verify(() => fetchStarterPackUseCase(const NoParams())).called(2);
      expect(bloc.state.step, OnboardingV2Step.starterPack);
    },
  );

  group('AI prompt for the interests', () {
    Future<OnboardingV2State> confirmStarterPackWith(OnboardingV2Bloc bloc, List<String> interests) async {
      app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
      for (final interest in interests) {
        bloc.add(OnboardingV2Event.interestToggled(interest));
      }
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.interestsConfirmed());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
      bloc.add(const OnboardingV2Event.starterPackConfirmed());
      return bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.aiGenerate);
    }

    setUp(() {
      when(() => saveInterestsUseCase(any())).thenAnswer((_) async => Result.success(null));
      when(() => followStarterPackUseCase(any())).thenAnswer((_) async => Result.success(null));
      when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
        (_) async =>
            Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
      );
    });

    test('an anime interest gets an anime style with a prompt from its pool', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      final state = await confirmStarterPackWith(bloc, <String>['Anime', 'Space', 'Tech']);

      expect(state.aiData.stylePreset, AiStylePreset.anime);
      expect(OnboardingV2Config.aiOnboardingPromptPool[AiStylePreset.anime], contains(state.aiData.prompt));
    });

    test('a very short interest name does not match a keyword by accident', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      final state = await confirmStarterPackWith(bloc, <String>['a', 'Cooking', 'Sports']);

      expect(OnboardingV2Config.aiOnboardingStyles, contains(state.aiData.stylePreset));
      expect(OnboardingV2Config.aiOnboardingPromptPool[state.aiData.stylePreset], contains(state.aiData.prompt));
    });

    test('every style the interest map can return has prompts', () {
      for (final style in OnboardingV2Config.aiInterestStyleMap.values.toSet()) {
        expect(OnboardingV2Config.aiOnboardingPromptPool[style], isNotEmpty, reason: '$style has no prompts');
      }
    });
  });

  group('AI generation', () {
    setUp(() {
      when(
        () => aiRepository.generate(
          prompt: any(named: 'prompt'),
          stylePreset: any(named: 'stylePreset'),
          qualityTier: any(named: 'qualityTier'),
          targetSize: any(named: 'targetSize'),
          chargeMode: any(named: 'chargeMode'),
          coinsSpent: any(named: 'coinsSpent'),
        ),
      ).thenAnswer((_) async => _aiRecord());
    });

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a generated image becomes the first wallpaper',
      build: buildBloc,
      act: (bloc) => bloc.add(const OnboardingV2Event.aiGenerationRequested(targetSize: '1080x1920')),
      wait: Duration.zero,
      verify: (bloc) {
        expect(bloc.state.aiData.status, AiGenerateStatus.success);
        expect(bloc.state.wallpaperData.wallpaper?.fullUrl, 'https://example.com/full.jpg');
        expect(bloc.state.wallpaperData.wallpaper?.thumbnailUrl, 'https://example.com/thumb.jpg');
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a failed generation is reported and leaves the wallpaper alone',
      setUp: () => when(
        () => aiRepository.generate(
          prompt: any(named: 'prompt'),
          stylePreset: any(named: 'stylePreset'),
          qualityTier: any(named: 'qualityTier'),
          targetSize: any(named: 'targetSize'),
          chargeMode: any(named: 'chargeMode'),
          coinsSpent: any(named: 'coinsSpent'),
        ),
      ).thenThrow(Exception('offline')),
      build: buildBloc,
      act: (bloc) => bloc.add(const OnboardingV2Event.aiGenerationRequested(targetSize: '1080x1920')),
      wait: Duration.zero,
      verify: (bloc) {
        expect(bloc.state.aiData.status, AiGenerateStatus.failure);
        expect(bloc.state.wallpaperData.wallpaper, isNull);
      },
    );
  });

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'stepping back walks the steps in reverse and stops at auth',
    setUp: () => app_state.prismUser = _user(id: 'resume-user', loggedIn: true),
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
      bloc.add(const OnboardingV2Event.stepBack());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.auth);
      bloc.add(const OnboardingV2Event.stepBack());
    },
    verify: (bloc) => expect(bloc.state.step, OnboardingV2Step.auth),
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'records first-wallpaper exposure on entry and action outcome after the platform call',
    setUp: () {
      when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer(
        (_) async => const OnboardingWallpaperVm(
          fullUrl: 'https://example.com/wall.jpg',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          sourceCategory: 'Nature',
        ),
      );
      when(() => firstWallpaperService.performAction(any())).thenAnswer((_) async => false);
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
      bloc.add(const OnboardingV2Event.aiGenerationStepContinued());
      await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.firstWallpaper);
      bloc.add(const OnboardingV2Event.firstWallpaperActionRequested());
    },
    wait: Duration.zero,
    verify: (_) {
      expect(
        trackedNames(),
        containsAll(<String>['onboarding_v2_first_wallpaper_shown', 'onboarding_v2_first_wallpaper_action']),
      );
      final action = analytics.events.singleWhere((e) => e.eventName == 'onboarding_v2_first_wallpaper_action');
      expect(action.toWireParameters()['result'], 'failure');
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'records onboarding completion once, only after persistence succeeds',
    setUp: () {
      when(() => completeOnboardingUseCase(any())).thenAnswer((_) async => Result.success(null));
    },
    build: buildBloc,
    act: (bloc) {
      bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: true));
      bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: true));
    },
    verify: (_) {
      final completion = analytics.events.where((e) => e.eventName == 'onboarding_v2_completed').toList();
      expect(completion, hasLength(1));
      expect(completion.single.toWireParameters()['did_purchase'], 1);
      expect(completion.single.toWireParameters()['total_elapsed_ms'], isA<int>());
      verify(() => completeOnboardingUseCase(any())).called(1);
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'existing premium completes onboarding without claiming a new purchase',
    setUp: () {
      app_state.prismUser = _user(id: 'premium-user', loggedIn: true, premium: true);
      when(
        () => onboardingRepository.fetchUserCompletionStatus(userId: 'premium-user'),
      ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: true, hasFollows: true)));
      when(() => completeOnboardingUseCase(any())).thenAnswer((_) async => Result.success(null));
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const OnboardingV2Event.started()),
    verify: (_) {
      final event = analytics.events.singleWhere((e) => e.eventName == 'onboarding_v2_completed');
      expect(event.toWireParameters()['did_purchase'], 0);
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'does not record onboarding completion when persistence fails',
    setUp: () {
      when(
        () => completeOnboardingUseCase(any()),
      ).thenAnswer((_) async => Result.error(const ServerFailure('write failed')));
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: false)),
    verify: (_) => expect(analytics.events, isEmpty),
  );
}
