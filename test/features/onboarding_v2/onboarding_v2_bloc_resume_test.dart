// Firebase's own platform-interface packages are transitive (pulled in via firebase_core and
// firebase_remote_config, not listed directly in pubspec.yaml) but needed here to stand up a
// fake FirebaseRemoteConfig for the test — see the comment on _FakeFirebaseRemoteConfigPlatform.
// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
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
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_remote_config_platform_interface/firebase_remote_config_platform_interface.dart';
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

class _RecordingAnalytics extends FakeAppAnalytics {
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];

  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event);
}

// The bloc reaches into `FirebaseRemoteConfig.instance` directly, which needs a real
// Firebase app to exist. `setupFirebaseCoreMocks()` mocks firebase_core's pigeon channel so
// `Firebase.initializeApp()` succeeds; this fake stands in for the remote config platform so
// `getString` doesn't hit a real (unmocked) platform channel.
class _FakeFirebaseRemoteConfigPlatform extends FirebaseRemoteConfigPlatform {
  @override
  FirebaseRemoteConfigPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseRemoteConfigPlatform setInitialValues({required Map<Object?, Object?> remoteConfigValues}) => this;

  @override
  String getString(String key) => '';
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only an actual paywall purchase counts as onboarding purchase', () {
    expect(PaywallResultValue.purchased.indicatesPurchase, isTrue);
    expect(PaywallResultValue.restored.indicatesPurchase, isFalse);
    expect(PaywallResultValue.cancelled.indicatesPurchase, isFalse);
  });

  late _MockFetchStarterPackUseCase fetchStarterPackUseCase;
  late _MockSaveInterestsUseCase saveInterestsUseCase;
  late _MockFollowStarterPackUseCase followStarterPackUseCase;
  late _MockCompleteOnboardingV2UseCase completeOnboardingUseCase;
  late _MockFirstWallpaperService firstWallpaperService;
  late _MockCategoryFeedRepository categoryFeedRepository;
  late _MockOnboardingV2Repository onboardingRepository;
  late _MockSettingsLocalDataSource settingsLocalDataSource;

  setUpAll(() async {
    registerFallbackValue(const <String>[]);
    registerFallbackValue(const SaveInterestsParams(interests: <String>[]));
    registerFallbackValue(const FollowStarterPackParams(creators: <OnboardingCreatorFollowParams>[]));
    registerFallbackValue(const CompleteOnboardingParams(didPurchase: false, totalElapsedMs: 0));
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseRemoteConfigPlatform.instance = _FakeFirebaseRemoteConfigPlatform();
  });

  setUp(() {
    AnalyticsRuntime.instance = _RecordingAnalytics();
    fetchStarterPackUseCase = _MockFetchStarterPackUseCase();
    saveInterestsUseCase = _MockSaveInterestsUseCase();
    followStarterPackUseCase = _MockFollowStarterPackUseCase();
    completeOnboardingUseCase = _MockCompleteOnboardingV2UseCase();
    firstWallpaperService = _MockFirstWallpaperService();
    categoryFeedRepository = _MockCategoryFeedRepository();
    onboardingRepository = _MockOnboardingV2Repository();
    settingsLocalDataSource = _MockSettingsLocalDataSource();

    getIt.registerSingleton<SettingsLocalDataSource>(settingsLocalDataSource);

    // PersonalizedInterestsCatalog.load falls through remote (empty, see fake remote config
    // above) and this cache miss to the built-in default catalog, which is non-empty — so
    // _onStarted never calls categoryFeedRepository.getCategories().
    when(
      () => settingsLocalDataSource.get<String>(app_constants.personalizedInterestsLocalCacheKey, defaultValue: ''),
    ).thenReturn('');
    when(
      () => fetchStarterPackUseCase(const FetchStarterPackParams()),
    ).thenAnswer((_) async => Result.success(<OnboardingStarterCreatorEntity>[]));
    when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer((_) async => null);
    when(
      () => onboardingRepository.fetchUserCompletionStatus(userId: 'resume-user'),
    ).thenAnswer((_) async => Result.success(const OnboardingUserStatus(hasInterests: false, hasFollows: false)));
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  OnboardingV2Bloc buildBloc() => OnboardingV2Bloc(
    fetchStarterPackUseCase,
    saveInterestsUseCase,
    followStarterPackUseCase,
    completeOnboardingUseCase,
    firstWallpaperService,
    categoryFeedRepository,
    onboardingRepository,
  );

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
    'records selected interests only after saving succeeds',
    setUp: () {
      when(() => saveInterestsUseCase(any())).thenAnswer((_) async => Result.success(null));
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.interestToggled('Nature'));
      bloc.add(const OnboardingV2Event.interestToggled('Anime'));
      bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.interestsConfirmed());
    },
    verify: (_) {
      final events = (AnalyticsRuntime.instance as _RecordingAnalytics).events;
      expect(events.map((event) => event.eventName), contains('onboarding_v2_interests_completed'));
      expect(
        events.singleWhere((event) => event.eventName == 'onboarding_v2_interests_completed').toWireParameters(),
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
      bloc.add(const OnboardingV2Event.interestToggled('Nature'));
      bloc.add(const OnboardingV2Event.interestToggled('Anime'));
      bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.interestsConfirmed());
    },
    verify: (_) {
      final events = (AnalyticsRuntime.instance as _RecordingAnalytics).events;
      expect(events, isEmpty);
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'records starter-pack follows after the follow write succeeds',
    setUp: () {
      when(() => followStarterPackUseCase(any())).thenAnswer((_) async => Result.success(null));
      when(() => fetchStarterPackUseCase(const FetchStarterPackParams())).thenAnswer(
        (_) async => Result.success(
          List<OnboardingStarterCreatorEntity>.generate(
            OnboardingV2Config.minFollows,
            (i) => OnboardingStarterCreatorEntity(
              userId: 'creator-$i',
              email: 'creator-$i@example.com',
              name: 'Creator $i',
              photoUrl: '',
              previewUrls: const <String>[],
              rank: i,
              bio: '',
              followerCount: 0,
            ),
          ),
        ),
      );
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.starterPackConfirmed());
    },
    verify: (_) {
      final event = (AnalyticsRuntime.instance as _RecordingAnalytics).events.singleWhere(
        (event) => event.eventName == 'onboarding_v2_starter_pack_completed',
      );
      expect(event.toWireParameters(), <String, Object?>{'followed_count': OnboardingV2Config.minFollows});
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'records first-wallpaper exposure on entry and action outcome after the platform call',
    setUp: () {
      when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer(
        (_) async => const OnboardingWallpaperVm(
          fullUrl: 'https://example.com/wall.jpg',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          title: 'Wall',
          authorName: 'Creator',
          sourceCategory: 'Nature',
        ),
      );
      when(() => firstWallpaperService.performAction(any())).thenAnswer((_) async => false);
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.aiGenerationStepContinued());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const OnboardingV2Event.firstWallpaperActionRequested());
    },
    verify: (_) {
      final events = (AnalyticsRuntime.instance as _RecordingAnalytics).events;
      expect(
        events.map((event) => event.eventName),
        containsAll(<String>['onboarding_v2_first_wallpaper_shown', 'onboarding_v2_first_wallpaper_action']),
      );
      final action = events.singleWhere((event) => event.eventName == 'onboarding_v2_first_wallpaper_action');
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
      final events = (AnalyticsRuntime.instance as _RecordingAnalytics).events;
      final completion = events.where((event) => event.eventName == 'onboarding_v2_completed').toList();
      expect(completion, hasLength(1));
      expect(completion.single.toWireParameters()['did_purchase'], 1);
      verify(() => completeOnboardingUseCase(any())).called(1);
    },
  );

  blocTest<OnboardingV2Bloc, OnboardingV2State>(
    'completion duration starts when onboarding starts',
    setUp: () {
      when(() => completeOnboardingUseCase(any())).thenAnswer((_) async => Result.success(null));
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const OnboardingV2Event.started());
      await Future<void>.delayed(const Duration(milliseconds: 15));
      bloc.add(const OnboardingV2Event.paywallResultReceived(didPurchase: false));
    },
    verify: (_) {
      final event = (AnalyticsRuntime.instance as _RecordingAnalytics).events.singleWhere(
        (event) => event.eventName == 'onboarding_v2_completed',
      );
      final parameters = event.toWireParameters();
      expect(parameters['did_purchase'], 0);
      expect(parameters['total_elapsed_ms']! as int, greaterThanOrEqualTo(10));
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
      final event = (AnalyticsRuntime.instance as _RecordingAnalytics).events.singleWhere(
        (event) => event.eventName == 'onboarding_v2_completed',
      );
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
    verify: (_) {
      final events = (AnalyticsRuntime.instance as _RecordingAnalytics).events;
      expect(events, isEmpty);
    },
  );
}
