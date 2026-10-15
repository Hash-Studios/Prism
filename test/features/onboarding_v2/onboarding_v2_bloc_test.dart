import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
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
    when(() => settingsLocalDataSource.set(any(), any())).thenAnswer((_) async {});
    when(
      () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
    ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: false, hasFollows: false)));
  });

  tearDown(() {
    OnboardingV2Bloc.completionRetryDelays = const <Duration>[
      Duration(seconds: 3),
      Duration(seconds: 10),
      Duration(seconds: 30),
    ];
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
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
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
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
      bloc.add(const OnboardingV2Event.interestToggled('Nature'));
      bloc.add(const OnboardingV2Event.interestToggled('Anime'));
      bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.interestsConfirmed());
    },
    verify: (_) => expect(trackedNames(), isNot(contains('onboarding_v2_interests_completed'))),
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'records starter-pack follows after the follow write succeeds',
    setUp: () {
      when(() => followStarterPackUseCase(any())).thenAnswer((_) async => Result.success(null));
      when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
        (_) async =>
            Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
      );
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
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

  group('AI prompt for the interests', () {
    Future<OnboardingV2State> confirmStarterPackWith(OnboardingV2Bloc bloc, List<String> interests) async {
      for (final interest in interests) {
        bloc.add(OnboardingV2Event.interestToggled(interest));
      }
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
      bloc.add(const OnboardingV2Event.starterPackConfirmed());
      return bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.aiGenerate);
    }

    setUp(() {
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

  test('stepping back walks the steps in reverse and then exits instead of showing auth', () async {
    app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
    final bloc = buildBloc();
    addTearDown(bloc.close);
    final requests = <OnboardingV2NavRequest>[];
    final sub = bloc.stream.listen((s) {
      if (s.navRequest != null) requests.add(s.navRequest!);
    });
    addTearDown(sub.cancel);

    bloc.add(const OnboardingV2Event.started());
    await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
    bloc.add(const OnboardingV2Event.interestsSkipped());
    await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
    bloc.add(const OnboardingV2Event.starterPackSkipped());
    await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.aiGenerate);

    bloc.add(const OnboardingV2Event.stepBack());
    await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
    bloc.add(const OnboardingV2Event.stepBack());
    await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
    bloc.add(const OnboardingV2Event.stepBack());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.step, OnboardingV2Step.interests);
    expect(requests, <OnboardingV2NavRequest>[OnboardingV2NavRequest.exitApp]);
  });

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
      when(
        () => firstWallpaperService.performAction(any()),
      ).thenAnswer((_) async => const FirstWallpaperResult(success: false, errorCode: 'PHOTO_PERMISSION_DENIED'));
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
      expect(trackedNames(), isNot(contains('onboarding_step_completed')));
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

  group('completion failure', () {
    setUp(() {
      OnboardingV2Bloc.completionRetryDelays = const <Duration>[Duration(milliseconds: 1), Duration(milliseconds: 1)];
    });

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a failed server write still lets the user in, stores the local flag first and reports the failure',
      setUp: () => when(
        () => completeOnboardingUseCase(any()),
      ).thenAnswer((_) async => Result.error(const ServerFailure('write failed'))),
      build: buildBloc,
      act: (bloc) => bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: false)),
      verify: (bloc) {
        verify(() => settingsLocalDataSource.set('onboarded_v2_new', true)).called(1);
        expect(bloc.state.actionStatus, ActionStatus.failure);
        expect(bloc.state.navRequest, OnboardingV2NavRequest.completeOnboarding);
        expect(trackedNames(), isNot(contains('onboarding_v2_completed')));
      },
    );

    test('the server write is retried in the background and recorded once it succeeds', () async {
      var calls = 0;
      when(() => completeOnboardingUseCase(any())).thenAnswer((_) async {
        calls++;
        return calls < 3 ? Result.error(const ServerFailure('offline')) : Result.success(null);
      });
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: true));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(calls, 3);
      final completion = analytics.events.where((e) => e.eventName == 'onboarding_v2_completed').toList();
      expect(completion, hasLength(1));
      expect(completion.single.toWireParameters()['did_purchase'], 1);
    });

    test('after the paywall was handled a later continue does not open it again', () async {
      when(() => completeOnboardingUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('x')));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: false));
      await bloc.stream.firstWhere((s) => s.navRequest == OnboardingV2NavRequest.completeOnboarding);
      final nextRequests = <OnboardingV2NavRequest?>[];
      final sub = bloc.stream.listen((s) => nextRequests.add(s.navRequest));
      bloc.add(const OnboardingV2Event.firstWallpaperStepContinued());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(nextRequests, isNot(contains(OnboardingV2NavRequest.openPaywall)));
      verify(() => completeOnboardingUseCase(any())).called(greaterThanOrEqualTo(2));
    });
  });

  group('returning user', () {
    setUp(() {
      app_state.prismUser = _user(id: 'returning', loggedIn: true);
      when(() => onboardingRepository.fetchUserCompletionStatus(userId: 'returning')).thenAnswer(
        (_) async =>
            Result.success(const OnboardingUserStatus(hasInterests: false, hasFollows: false, completed: true)),
      );
    });

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a user the server marks completed skips every step and the paywall',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.navRequest != null);
      },
      verify: (bloc) {
        expect(bloc.state.navRequest, OnboardingV2NavRequest.completeOnboarding);
        expect(bloc.state.step, OnboardingV2Step.auth);
        verify(() => settingsLocalDataSource.set('onboarded_v2_new', true)).called(1);
        verifyNever(() => completeOnboardingUseCase(any()));
        expect(trackedNames(), isNot(contains('onboarding_v2_completed')));
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a non-premium returning user is never sent to the paywall',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.authCompleted());
        await bloc.stream.firstWhere((s) => s.navRequest != null);
      },
      verify: (bloc) => expect(bloc.state.navRequest, isNot(OnboardingV2NavRequest.openPaywall)),
    );
  });

  group('starter pack and interests skipping', () {
    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a starter pack with fewer creators than the minimum can continue once all are picked',
      setUp: () => when(
        () => fetchStarterPackUseCase(const NoParams()),
      ).thenAnswer((_) async => Result.success(<OnboardingStarterCreatorEntity>[_creator(0), _creator(1)])),
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
      },
      verify: (bloc) {
        expect(bloc.state.starterPackData.requiredCount, 2);
        expect(bloc.state.starterPackData.canContinue, isTrue);
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'an empty starter pack cannot continue but can be skipped to the AI step',
      setUp: () => app_state.prismUser = _user(id: 'resume-user', loggedIn: true),
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestsSkipped());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
        expect(bloc.state.starterPackData.canContinue, isFalse);
        bloc.add(const OnboardingV2Event.starterPackSkipped());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.aiGenerate);
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.aiGenerate);
        verifyNever(() => followStarterPackUseCase(any()));
        verifyNever(() => saveInterestsUseCase(any()));
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'skipping interests when the follows are already done goes to the AI step with a prompt',
      setUp: () {
        app_state.prismUser = _user(id: 'follower', loggedIn: true);
        when(
          () => onboardingRepository.fetchUserCompletionStatus(userId: 'follower'),
        ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: false, hasFollows: true)));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestsSkipped());
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingV2Step.aiGenerate);
        expect(bloc.state.aiData.prompt, isNotEmpty);
      },
    );

    test('interests need min(3, available) picks and an empty list never continues', () {
      const base = OnboardingInterestsData(available: <String>['a', 'b'], selected: <String>[], categoryImages: {});
      expect(base.requiredCount, 2);
      expect(base.canContinue, isFalse);
      expect(base.copyWith(selected: <String>['a', 'b']).canContinue, isTrue);
      expect(OnboardingInterestsData.initial().canContinue, isFalse);
    });

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'retrying a failed load fetches the catalogue again',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
        bloc.add(const OnboardingV2Event.loadRetried());
        await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.loading);
        await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
      },
      verify: (_) => verify(() => fetchStarterPackUseCase(const NoParams())).called(2),
    );
  });

  group('back navigation', () {
    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'back on the auth step asks the shell to exit the app',
      build: buildBloc,
      act: (bloc) => bloc.add(const OnboardingV2Event.stepBack()),
      expect: () => <Matcher>[
        isA<OnboardingV2State>().having((s) => s.navRequest, 'navRequest', OnboardingV2NavRequest.exitApp),
        isA<OnboardingV2State>().having((s) => s.navRequest, 'navRequest', isNull),
      ],
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'a signed-in user on the first step never goes back to auth',
      setUp: () => app_state.prismUser = _user(id: 'resume-user', loggedIn: true),
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.stepBack());
      },
      verify: (bloc) => expect(bloc.state.step, OnboardingV2Step.interests),
    );
  });

  group('analytics funnel', () {
    int stepCompletions(String step) => analytics.events
        .where((e) => e.eventName == 'onboarding_step_completed' && e.toWireParameters()['step'] == step)
        .length;

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'starting onboarding records onboarding_started once',
      build: buildBloc,
      act: (bloc) => bloc.add(const OnboardingV2Event.started()),
      verify: (_) => expect(trackedNames().where((n) => n == 'onboarding_started'), hasLength(1)),
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'each finished step records onboarding_step_completed with its name',
      setUp: () {
        app_state.prismUser = _user(id: 'resume-user', loggedIn: true);
        when(() => saveInterestsUseCase(any())).thenAnswer((_) async => Result.success(null));
        when(() => followStarterPackUseCase(any())).thenAnswer((_) async => Result.success(null));
        when(() => fetchStarterPackUseCase(const NoParams())).thenAnswer(
          (_) async =>
              Result.success(List<OnboardingStarterCreatorEntity>.generate(OnboardingV2Config.minFollows, _creator)),
        );
        when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer(
          (_) async => const OnboardingWallpaperVm(
            fullUrl: 'https://example.com/wall.jpg',
            thumbnailUrl: 'https://example.com/thumb.jpg',
            sourceCategory: 'Nature',
          ),
        );
        when(
          () => firstWallpaperService.performAction(any()),
        ).thenAnswer((_) async => const FirstWallpaperResult(success: true, target: WallpaperTarget.both));
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
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        for (final interest in <String>['Nature', 'Anime', 'Minimal']) {
          bloc.add(OnboardingV2Event.interestToggled(interest));
        }
        bloc.add(const OnboardingV2Event.interestsConfirmed());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
        bloc.add(const OnboardingV2Event.starterPackConfirmed());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.aiGenerate);
        bloc.add(const OnboardingV2Event.aiGenerationRequested(targetSize: '1080x1920'));
        await bloc.stream.firstWhere((s) => s.aiData.status == AiGenerateStatus.success);
        bloc.add(const OnboardingV2Event.aiGenerationStepContinued());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.firstWallpaper);
        bloc.add(const OnboardingV2Event.firstWallpaperActionRequested());
        await bloc.stream.firstWhere((s) => s.wallpaperData.status == FirstWallpaperStatus.success);
      },
      verify: (_) {
        for (final step in <String>['auth', 'interests', 'starter_pack', 'ai_generate', 'first_wallpaper']) {
          expect(stepCompletions(step), 1, reason: step);
        }
      },
    );

    blocTest<OnboardingV2Bloc, OnboardingV2State>(
      'skipping the AI step does not count it as completed',
      setUp: () => app_state.prismUser = _user(id: 'resume-user', loggedIn: true),
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const OnboardingV2Event.started());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
        bloc.add(const OnboardingV2Event.interestsSkipped());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
        bloc.add(const OnboardingV2Event.starterPackSkipped());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.aiGenerate);
        bloc.add(const OnboardingV2Event.aiGenerationStepContinued());
        await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.firstWallpaper);
      },
      verify: (_) {
        expect(stepCompletions('ai_generate'), 0);
        expect(stepCompletions('interests'), 0);
      },
    );
  });

  group('first wallpaper outcome', () {
    setUp(() {
      when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer(
        (_) async => const OnboardingWallpaperVm(
          fullUrl: 'https://example.com/wall.jpg',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          sourceCategory: 'Nature',
        ),
      );
    });

    Future<void> request(OnboardingV2Bloc bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
      bloc.add(const OnboardingV2Event.firstWallpaperActionRequested());
    }

    test('a success keeps the screen that was set so the toast can name it', () async {
      when(
        () => firstWallpaperService.performAction(any()),
      ).thenAnswer((_) async => const FirstWallpaperResult(success: true, target: WallpaperTarget.home));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      await request(bloc);
      final state = await bloc.stream.firstWhere((s) => s.wallpaperData.status == FirstWallpaperStatus.success);

      expect(state.wallpaperData.target, WallpaperTarget.home);
      expect(state.wallpaperData.errorCode, isNull);
    });

    test('a failure keeps the error code and trying again clears it', () async {
      when(
        () => firstWallpaperService.performAction(any()),
      ).thenAnswer((_) async => const FirstWallpaperResult(success: false, errorCode: 'PHOTO_PERMISSION_DENIED'));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      await request(bloc);
      final failed = await bloc.stream.firstWhere((s) => s.wallpaperData.status == FirstWallpaperStatus.failure);
      expect(failed.wallpaperData.errorCode, 'PHOTO_PERMISSION_DENIED');

      bloc.add(const OnboardingV2Event.firstWallpaperActionRequested());
      final loading = await bloc.stream.firstWhere((s) => s.wallpaperData.status == FirstWallpaperStatus.loading);
      expect(loading.wallpaperData.errorCode, isNull);
    });
  });

  group('guest path', () {
    Future<void> startAsGuest(OnboardingV2Bloc bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
      bloc.add(const OnboardingV2Event.guestBrowseStarted());
      await bloc.stream.firstWhere((s) => s.isGuest);
    }

    void pickThree(OnboardingV2Bloc bloc) {
      for (final interest in <String>['Nature', 'Anime', 'Minimal']) {
        bloc.add(OnboardingV2Event.interestToggled(interest));
      }
    }

    test('browsing without an account opens the interests step', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      await startAsGuest(bloc);

      expect(bloc.state.step, OnboardingV2Step.interests);
      expect(bloc.state.isGuest, isTrue);
    });

    test('confirming stores the picks on the device only and opens the dashboard', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await startAsGuest(bloc);

      pickThree(bloc);
      bloc.add(const OnboardingV2Event.interestsConfirmed());
      final done = await bloc.stream.firstWhere((s) => s.navRequest != null);

      expect(done.navRequest, OnboardingV2NavRequest.openDashboardAsGuest);
      verify(() => settingsLocalDataSource.set('onboarding_v2_interests', 'Nature,Anime,Minimal')).called(1);
      verify(() => settingsLocalDataSource.set('onboarded_v2_new', true)).called(1);
      verifyNever(() => saveInterestsUseCase(any()));
      verifyNever(() => completeOnboardingUseCase(any()));
      expect(trackedNames(), containsAll(<String>['onboarding_v2_interests_completed', 'onboarding_step_completed']));
    });

    test('skipping opens the dashboard without storing interests', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await startAsGuest(bloc);

      bloc.add(const OnboardingV2Event.interestsSkipped());
      final done = await bloc.stream.firstWhere((s) => s.navRequest != null);

      expect(done.navRequest, OnboardingV2NavRequest.openDashboardAsGuest);
      verify(() => settingsLocalDataSource.set('onboarded_v2_new', true)).called(1);
      verifyNever(() => settingsLocalDataSource.set('onboarding_v2_interests', any()));
    });

    test('a failed local write reports the failure and stays on the step', () async {
      when(() => settingsLocalDataSource.set('onboarding_v2_interests', any())).thenThrow(StateError('disk full'));
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await startAsGuest(bloc);

      pickThree(bloc);
      bloc.add(const OnboardingV2Event.interestsConfirmed());
      final failed = await bloc.stream.firstWhere((s) => s.actionStatus == ActionStatus.failure);

      expect(failed.step, OnboardingV2Step.interests);
      expect(failed.navRequest, isNull);
      verifyNever(() => settingsLocalDataSource.set('onboarded_v2_new', true));
    });

    test('back returns a guest to the sign-in step and ends the guest path', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await startAsGuest(bloc);

      bloc.add(const OnboardingV2Event.stepBack());
      final back = await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.auth);

      expect(back.isGuest, isFalse);
      expect(back.navRequest, isNull);
    });
  });
}
