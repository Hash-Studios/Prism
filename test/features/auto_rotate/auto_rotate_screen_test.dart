import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/views/pages/auto_rotate_screen.dart';
import 'package:Prism/features/auto_rotate/views/widgets/auto_rotate_session_listener.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

class _MockSessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

class _MockStartupRepository extends Mock implements StartupRepository {}

void main() {
  late _MockAutoRotateBloc autoRotateBloc;
  late _MockFavouriteWallsBloc favouriteWallsBloc;
  late _MockSessionBloc sessionBloc;
  late _MockStartupRepository startupRepository;

  setUpAll(() {
    registerFallbackValue(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: false));
  });

  setUp(() async {
    await getIt.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    autoRotateBloc = _MockAutoRotateBloc();
    favouriteWallsBloc = _MockFavouriteWallsBloc();
    sessionBloc = _MockSessionBloc();
    startupRepository = _MockStartupRepository();
    when(() => favouriteWallsBloc.state).thenReturn(FavouriteWallsState.initial().copyWith(status: LoadStatus.success));
    when(() => sessionBloc.state).thenReturn(SessionState.initial().copyWith(status: LoadStatus.success));
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial());
    when(() => startupRepository.currentConfig).thenReturn(
      const StartupConfigEntity(
        topImageLink: '',
        bannerText: '',
        bannerTextOn: false,
        bannerUrl: '',
        obsoleteAppVersion: '',
        verifiedUsers: <String>[],
        premiumCollections: <String>[],
        aiEnabled: false,
        aiRolloutPercent: 0,
        aiSubmitEnabled: false,
        aiVariationsEnabled: false,
        useRcPaywalls: false,
        onboardingV2Enabled: false,
      ),
    );
    getIt.registerSingleton<StartupRepository>(startupRepository);
    getIt.registerFactory<AutoRotateBloc>(() => autoRotateBloc);
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AutoRotateBloc>.value(value: autoRotateBloc),
          BlocProvider<FavouriteWallsBloc>.value(value: favouriteWallsBloc),
          BlocProvider<SessionBloc>.value(value: sessionBloc),
        ],
        child: const AutoRotateSessionListener(child: AutoRotateScreen()),
      ),
    ),
  );

  testWidgets('shows a distinct retry state when favourites fail to load', (tester) async {
    when(() => favouriteWallsBloc.state).thenReturn(FavouriteWallsState.initial().copyWith(status: LoadStatus.failure));

    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('Could not load auto-rotate settings.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: false)));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('does not start Android rotation on unsupported platforms', (tester) async {
    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('Auto-rotate is only available on Android.'), findsOneWidget);
    verifyNever(() => autoRotateBloc.add(any()));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('keeps a failed native stop visible and retries it for a non-Pro user', (tester) async {
    when(() => autoRotateBloc.state).thenReturn(
      AutoRotateState.initial().copyWith(loaded: true, isPro: false, status: const AutoRotateStatus(isRunning: true)),
    );

    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('Could not stop wallpaper rotation.'), findsOneWidget);
    await tester.tap(find.text('Try again'));

    verify(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false))).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('refreshes session after the paywall returns dismissed', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..loggedIn = true
      ..id = 'signed-in';
    final StreamController<SessionState> sessionStates = StreamController<SessionState>.broadcast();
    addTearDown(sessionStates.close);
    const SessionEntity freeSession = SessionEntity(
      userId: 'signed-in',
      loggedIn: true,
      premium: false,
      subscriptionTier: 'free',
    );
    whenListen(
      sessionBloc,
      sessionStates.stream,
      initialState: const SessionState(status: LoadStatus.success, session: freeSession),
    );
    when(
      () => favouriteWallsBloc.state,
    ).thenReturn(FavouriteWallsState.initial().copyWith(status: LoadStatus.success, userId: 'signed-in'));
    final StreamController<AutoRotateState> autoRotateStates = StreamController<AutoRotateState>.broadcast();
    addTearDown(autoRotateStates.close);
    final AutoRotateState freeState = AutoRotateState.initial().copyWith(loaded: true, isPro: false);
    whenListen(autoRotateBloc, autoRotateStates.stream, initialState: freeState);

    await pumpScreen(tester);
    await tester.pump();
    await tester.tap(find.text('See Prism Pro'));
    await tester.pump();

    verify(() => sessionBloc.add(const SessionEvent.started())).called(1);

    const SessionEntity premiumSession = SessionEntity(
      userId: 'signed-in',
      loggedIn: true,
      premium: true,
      subscriptionTier: 'pro',
    );
    sessionStates.add(const SessionState(status: LoadStatus.success, session: premiumSession));
    await tester.pump();
    verify(
      () => autoRotateBloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'signed-in')),
    ).called(1);
    autoRotateStates.add(freeState.copyWith(isPro: true, favouriteCount: 2));
    await tester.pump();

    expect(find.text('Auto-rotate wallpapers'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('does not send favourites across an account change while loading', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..loggedIn = true
      ..premium = true
      ..id = 'account-a';
    final StreamController<SessionState> sessionStates = StreamController<SessionState>.broadcast();
    addTearDown(sessionStates.close);
    final StreamController<FavouriteWallsState> favouriteStates = StreamController<FavouriteWallsState>.broadcast();
    addTearDown(favouriteStates.close);
    const SessionEntity accountA = SessionEntity(
      userId: 'account-a',
      loggedIn: true,
      premium: true,
      subscriptionTier: 'pro',
    );
    const SessionEntity accountB = SessionEntity(
      userId: 'account-b',
      loggedIn: true,
      premium: false,
      subscriptionTier: 'free',
    );
    whenListen(
      sessionBloc,
      sessionStates.stream,
      initialState: const SessionState(status: LoadStatus.success, session: accountA),
    );
    whenListen(
      favouriteWallsBloc,
      favouriteStates.stream,
      initialState: FavouriteWallsState.initial().copyWith(status: LoadStatus.loading, userId: 'account-a'),
    );

    await pumpScreen(tester);
    await tester.pump();
    sessionStates.add(const SessionState(status: LoadStatus.success, session: accountB));
    favouriteStates.add(FavouriteWallsState.initial().copyWith(status: LoadStatus.success, userId: 'account-a'));
    await tester.pump();

    expect(find.text('Could not load auto-rotate settings.'), findsOneWidget);
    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true)));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('retries a failed manual wallpaper change without stopping rotation', (tester) async {
    when(() => autoRotateBloc.state).thenReturn(
      AutoRotateState.initial().copyWith(
        loaded: true,
        isPro: true,
        favouriteCount: 2,
        config: const AutoRotateConfig(enabled: true),
        status: const AutoRotateStatus(isRunning: true, lastError: 'apply_failed'),
      ),
    );

    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('Could not change wallpaper.'), findsOneWidget);
    await tester.tap(find.text('Change now'));

    verify(() => autoRotateBloc.add(const AutoRotateEvent.rotateNowPressed())).called(1);
    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false)));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('disposal leaves the shared AutoRotateBloc open', (tester) async {
    await pumpScreen(tester);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    verifyNever(() => autoRotateBloc.close());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('does not dispatch after disposal while waiting for the session', (tester) async {
    final StreamController<SessionState> sessionStates = StreamController<SessionState>.broadcast();
    addTearDown(sessionStates.close);
    whenListen(sessionBloc, sessionStates.stream, initialState: SessionState.initial());

    await pumpScreen(tester);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    sessionStates.add(SessionState.initial().copyWith(status: LoadStatus.success));
    await tester.pump();

    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: false)));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  group('controls', () {
    AutoRotateState proState({
      AutoRotateConfig config = const AutoRotateConfig(enabled: true),
      AutoRotateStatus status = const AutoRotateStatus(isRunning: true),
      int favouriteCount = 3,
      int downloadCount = 0,
      bool starting = false,
      bool sourcesCapped = false,
      bool showBatteryTip = false,
    }) => AutoRotateState.initial().copyWith(
      loaded: true,
      isPro: true,
      config: config,
      status: status,
      favouriteCount: favouriteCount,
      downloadCount: downloadCount,
      starting: starting,
      sourcesCapped: sourcesCapped,
      showBatteryTip: showBatteryTip,
    );

    Future<void> pumpControls(WidgetTester tester, AutoRotateState state) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      when(() => autoRotateBloc.state).thenReturn(state);
      await pumpScreen(tester);
      await tester.pump();
    }

    testWidgets('shows a preparing row and a switch that stays on while starting', (tester) async {
      await pumpControls(
        tester,
        proState(config: const AutoRotateConfig(), status: const AutoRotateStatus(), starting: true),
      );

      expect(find.text('Preparing 3 wallpapers'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Auto-rotate wallpapers')).value,
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Auto-rotate wallpapers')).onChanged,
        isNull,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('shows cached of total and the cap note', (tester) async {
      await pumpControls(
        tester,
        proState(
          favouriteCount: 100,
          sourcesCapped: true,
          status: const AutoRotateStatus(isRunning: true, cachedCount: 40, totalCount: 100),
        ),
      );

      expect(find.text('Downloaded 40 of 100 wallpapers'), findsOneWidget);
      expect(find.textContaining('Using your first 100'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('lets the user switch the source and the charging option', (tester) async {
      await pumpControls(tester, proState());

      await tester.tap(find.text('Downloads'));
      await tester.tap(find.text('Only while charging'));

      verify(() => autoRotateBloc.add(const AutoRotateEvent.sourceChanged(AutoRotateSource.downloads))).called(1);
      verify(() => autoRotateBloc.add(const AutoRotateEvent.chargingOnlyChanged(true))).called(1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('has no active hours control', (tester) async {
      await pumpControls(tester, proState());

      expect(find.text('Active hours'), findsNothing);
      expect(find.text('From'), findsNothing);
      expect(find.text('Until'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('keeps the controls with a notice when the source has too few wallpapers', (tester) async {
      await pumpControls(
        tester,
        proState(config: const AutoRotateConfig(), status: const AutoRotateStatus(), favouriteCount: 1),
      );

      expect(find.text('Favourite at least 2 wallpapers to rotate them.'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Auto-rotate wallpapers')).onChanged,
        isNull,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('shows the battery tip once and lets the user dismiss it', (tester) async {
      await pumpControls(tester, proState(showBatteryTip: true));

      expect(find.textContaining('set battery use for Prism to Unrestricted'), findsOneWidget);
      await tester.tap(find.text('Got it'));

      verify(() => autoRotateBloc.add(const AutoRotateEvent.batteryTipDismissed())).called(1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
