import 'dart:async';

import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/complete_onboarding_v2_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/fetch_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/follow_starter_pack_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/services/first_wallpaper_service.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_wallpaper_vm.j.dart';
import 'package:Prism/features/taste_quiz/domain/repositories/taste_quiz_repository.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../taste_quiz/taste_quiz_fixtures.dart';

class _MockFetchStarterPackUseCase extends Mock implements FetchStarterPackUseCase {}

class _MockSaveInterestsUseCase extends Mock implements SaveInterestsUseCase {}

class _MockFollowStarterPackUseCase extends Mock implements FollowStarterPackUseCase {}

class _MockCompleteOnboardingV2UseCase extends Mock implements CompleteOnboardingV2UseCase {}

class _MockFirstWallpaperService extends Mock implements FirstWallpaperService {}

class _MockCategoryFeedRepository extends Mock implements CategoryFeedRepository {}

class _MockOnboardingV2Repository extends Mock implements OnboardingV2Repository {}

class _MockSettingsLocalDataSource extends Mock implements SettingsLocalDataSource {}

class _MockFirebaseRemoteConfig extends Mock implements FirebaseRemoteConfig {}

class _MockTasteQuizRepository extends Mock implements TasteQuizRepository {}

PrismUsersV2 _user({required String id, required bool loggedIn}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return PrismUsersV2(
    username: '',
    email: 'resume@example.com',
    id: id,
    createdAt: now,
    premium: false,
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

  late _MockFetchStarterPackUseCase fetchStarterPackUseCase;
  late _MockSaveInterestsUseCase saveInterestsUseCase;
  late _MockFollowStarterPackUseCase followStarterPackUseCase;
  late _MockCompleteOnboardingV2UseCase completeOnboardingUseCase;
  late _MockFirstWallpaperService firstWallpaperService;
  late _MockCategoryFeedRepository categoryFeedRepository;
  late _MockOnboardingV2Repository onboardingRepository;
  late _MockSettingsLocalDataSource settingsLocalDataSource;
  late _MockFirebaseRemoteConfig remoteConfig;
  late _MockTasteQuizRepository tasteQuizRepository;

  setUpAll(() {
    registerFallbackValue(const SaveInterestsParams(interests: <String>[]));
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    fetchStarterPackUseCase = _MockFetchStarterPackUseCase();
    saveInterestsUseCase = _MockSaveInterestsUseCase();
    followStarterPackUseCase = _MockFollowStarterPackUseCase();
    completeOnboardingUseCase = _MockCompleteOnboardingV2UseCase();
    firstWallpaperService = _MockFirstWallpaperService();
    categoryFeedRepository = _MockCategoryFeedRepository();
    onboardingRepository = _MockOnboardingV2Repository();
    settingsLocalDataSource = _MockSettingsLocalDataSource();
    remoteConfig = _MockFirebaseRemoteConfig();
    tasteQuizRepository = _MockTasteQuizRepository();

    app_state.prismUser = _user(id: 'resume-user', loggedIn: true);

    // Empty remote config and cache make PersonalizedInterestsCatalog fall back to the built-in catalog.
    when(() => remoteConfig.getString(any())).thenReturn('');
    when(
      () => settingsLocalDataSource.get<String>(app_constants.personalizedInterestsLocalCacheKey, defaultValue: ''),
    ).thenReturn('');
    when(() => settingsLocalDataSource.set(any(), any())).thenAnswer((_) async {});
    when(
      () => fetchStarterPackUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.success(<OnboardingStarterCreatorEntity>[]));
    when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer((_) async => null);
    when(() => saveInterestsUseCase(any())).thenAnswer((_) async => Result.success(null));
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => null);
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
    tasteQuizRepository,
    remoteConfig: remoteConfig,
    loadLocalizations: () async => AppLocalizationsEn(),
  );

  /// Signed-in user, loaded, with three interests picked on the interests step.
  Future<void> reachInterests(OnboardingV2Bloc bloc) async {
    bloc.add(const OnboardingV2Event.started());
    await bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
    bloc.add(const OnboardingV2Event.interestToggled('Nature'));
    bloc.add(const OnboardingV2Event.interestToggled('Anime'));
    bloc.add(const OnboardingV2Event.interestToggled('Minimal'));
    await Future<void>.delayed(Duration.zero);
  }

  Future<OnboardingV2State> confirmInterests(OnboardingV2Bloc bloc) {
    final Future<OnboardingV2State> next = bloc.stream.firstWhere((s) => s.step != OnboardingV2Step.interests);
    bloc.add(const OnboardingV2Event.interestsConfirmed());
    return next;
  }

  test('confirming interests opens the quiz, and finishing it moves on to the starter pack', () async {
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => quizPlan());
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await reachInterests(bloc);

    final OnboardingV2State quizState = await confirmInterests(bloc);

    expect(quizState.step, OnboardingV2Step.tasteQuiz);
    expect(quizState.tasteQuizPlan, isNotNull);

    final Future<OnboardingV2State> next = bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
    bloc.add(const OnboardingV2Event.tasteQuizFinished(completed: true));
    final OnboardingV2State starter = await next;

    expect(starter.step, OnboardingV2Step.starterPack);
    expect(starter.skipStarterPack, isFalse);
    expect(starter.tasteQuizPlan, isNull);
  });

  test('skipping the quiz also moves on to the starter pack', () async {
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => quizPlan());
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await reachInterests(bloc);
    await confirmInterests(bloc);

    final Future<OnboardingV2State> next = bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
    bloc.add(const OnboardingV2Event.tasteQuizFinished(completed: false));
    final OnboardingV2State starter = await next;

    expect(starter.step, OnboardingV2Step.starterPack);
    expect(starter.skipStarterPack, isFalse);
    expect(starter.tasteQuizPlan, isNull);
  });

  test('a failed quiz load skips the quiz step', () async {
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => null);
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await reachInterests(bloc);

    final List<OnboardingV2State> states = <OnboardingV2State>[];
    final StreamSubscription<OnboardingV2State> sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);
    final OnboardingV2State starter = await confirmInterests(bloc);

    expect(starter.step, OnboardingV2Step.starterPack);
    expect(states.any((s) => s.step == OnboardingV2Step.tasteQuiz), isFalse);
  });

  test('a stalled recommendation after confirming interests does not block the next step', () async {
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => null);
    final Completer<OnboardingWallpaperVm?> stalledRecommendation = Completer<OnboardingWallpaperVm?>();
    when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer((invocation) {
      final interests = invocation.positionalArguments.single as List<String>;
      return interests.isEmpty ? Future<OnboardingWallpaperVm?>.value() : stalledRecommendation.future;
    });
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await reachInterests(bloc);

    try {
      final OnboardingV2State starter = await confirmInterests(bloc).timeout(const Duration(seconds: 5));

      expect(starter.step, OnboardingV2Step.starterPack);
      expect(starter.actionStatus, ActionStatus.success);
      expect(starter.wallpaperData.wallpaper, isNull);
    } finally {
      if (!stalledRecommendation.isCompleted) stalledRecommendation.complete(null);
    }
  });

  test('a failed recommendation after confirming interests falls back and continues', () async {
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => null);
    when(() => firstWallpaperService.recommendForOnboarding(any())).thenAnswer((invocation) {
      final interests = invocation.positionalArguments.single as List<String>;
      if (interests.isEmpty) return Future<OnboardingWallpaperVm?>.value();
      return Future<OnboardingWallpaperVm?>.error(StateError('category feed unavailable'));
    });
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await reachInterests(bloc);

    final OnboardingV2State starter = await confirmInterests(bloc);

    expect(starter.step, OnboardingV2Step.starterPack);
    expect(starter.actionStatus, ActionStatus.success);
    expect(starter.wallpaperData.wallpaper, isNull);
  });

  test('the quiz plan is requested once, with the selected interests', () async {
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => quizPlan());
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await reachInterests(bloc);

    await confirmInterests(bloc);

    verify(() => tasteQuizRepository.loadPlan(<String>['Nature', 'Anime', 'Minimal'])).called(1);
  });

  test('going back to interests and confirming again never offers the quiz twice', () async {
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => quizPlan());
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await reachInterests(bloc);
    expect((await confirmInterests(bloc)).step, OnboardingV2Step.tasteQuiz);

    final Future<OnboardingV2State> back = bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
    bloc.add(const OnboardingV2Event.stepBack());
    await back;

    final OnboardingV2State starter = await confirmInterests(bloc);

    expect(starter.step, OnboardingV2Step.starterPack);
    verify(() => tasteQuizRepository.loadPlan(any())).called(1);
  });

  test('going back from the starter pack after the quiz lands on interests, not the quiz', () async {
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => quizPlan());
    final bloc = buildBloc();
    addTearDown(bloc.close);
    await reachInterests(bloc);
    await confirmInterests(bloc);

    final Future<OnboardingV2State> starter = bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.starterPack);
    bloc.add(const OnboardingV2Event.tasteQuizFinished(completed: true));
    await starter;

    final Future<OnboardingV2State> back = bloc.stream.firstWhere((s) => s.step == OnboardingV2Step.interests);
    bloc.add(const OnboardingV2Event.stepBack());
    final OnboardingV2State interests = await back;

    expect(interests.step, OnboardingV2Step.interests);
  });

  test('iOS guests never get the quiz', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    app_state.prismUser = app_constants.createGuestPrismUser();
    when(() => tasteQuizRepository.loadPlan(any())).thenAnswer((_) async => quizPlan());
    final bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.add(const OnboardingV2Event.started());
    await bloc.stream.firstWhere((s) => s.loadStatus == LoadStatus.success);
    bloc.add(const OnboardingV2Event.guestBrowseStarted());
    await bloc.stream.firstWhere((s) => s.isGuest);
    for (final interest in <String>['Nature', 'Anime', 'Minimal']) {
      bloc.add(OnboardingV2Event.interestToggled(interest));
    }
    await Future<void>.delayed(Duration.zero);

    final Future<OnboardingV2State> done = bloc.stream.firstWhere((s) => s.navRequest != null);
    bloc.add(const OnboardingV2Event.interestsConfirmed());
    await done;

    verifyNever(() => tasteQuizRepository.loadPlan(any()));
  });
}
