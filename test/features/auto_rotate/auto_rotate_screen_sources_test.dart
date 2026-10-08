import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
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
import 'package:flutter/services.dart';
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
    final _MockStartupRepository startupRepository = _MockStartupRepository();
    when(() => favouriteWallsBloc.state).thenReturn(FavouriteWallsState.initial().copyWith(status: LoadStatus.success));
    when(() => sessionBloc.state).thenReturn(SessionState.initial().copyWith(status: LoadStatus.success));
    when(() => autoRotateBloc.state).thenReturn(_proState());
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async => true,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
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
    await tester.pump();
  }

  testWidgets('the failure state offers Turn off, never a Try again that turns rotation off', (tester) async {
    when(
      () => autoRotateBloc.state,
    ).thenReturn(_proState().copyWith(status: const AutoRotateStatus(lastError: 'Worker failed')));

    await pumpScreen(tester);

    expect(find.text('Could not update auto-rotate.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await tester.tap(find.text('Turn off'));
    verify(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false))).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('lists every interval, including the battery heavy one', (tester) async {
    await pumpScreen(tester);

    for (final String label in <String>[
      'Every 15 min (battery heavy)',
      'Every 30 min',
      'Every hour',
      'Every 3 hours',
      'Every 6 hours',
      'Every 12 hours',
      'Every day',
      'Every 3 days',
      'Every week',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Every week'));
    verify(() => autoRotateBloc.add(const AutoRotateEvent.intervalChanged(10080))).called(1);
    await tester.tap(find.text('Every 15 min (battery heavy)'));
    verify(() => autoRotateBloc.add(const AutoRotateEvent.intervalChanged(15))).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('offers the new sources and sends the chosen one', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Category'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    await tester.tap(find.text('Wall of the Day'));
    await tester.tap(find.text('History'));

    verify(() => autoRotateBloc.add(const AutoRotateEvent.sourceChanged(AutoRotateSource.wallOfTheDay))).called(1);
    verify(() => autoRotateBloc.add(const AutoRotateEvent.sourceChanged(AutoRotateSource.history))).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the category chip opens a picker with 18 names and sends the pick', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a category'), findsOneWidget);
    expect(find.text('Nature'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Galaxy'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Galaxy'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Space'), -200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Space'));
    await tester.pumpAndSettle();

    verify(() => autoRotateBloc.add(const AutoRotateEvent.categoryChanged('Space'))).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('shows the chosen category on the chip and counts its wallpapers', (tester) async {
    when(() => autoRotateBloc.state).thenReturn(
      _proState().copyWith(
        config: const AutoRotateConfig(source: AutoRotateSource.category, categoryName: 'Space'),
        remoteCount: 12,
      ),
    );

    await pumpScreen(tester);

    expect(find.text('Category: Space'), findsOneWidget);
    expect(find.text('12 Space wallpapers in the mix'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('says when a source cannot be loaded and retries by turning rotation on', (tester) async {
    when(() => autoRotateBloc.state).thenReturn(
      _proState().copyWith(
        config: const AutoRotateConfig(source: AutoRotateSource.wallOfTheDay),
        sourceLoadFailed: true,
      ),
    );

    await pumpScreen(tester);

    expect(find.text('Could not load wallpapers. Check your connection.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => autoRotateBloc.add(const AutoRotateEvent.toggled(true))).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('APPLY TO lists only the targets the device supports', (tester) async {
    when(
      () => autoRotateBloc.state,
    ).thenReturn(_proState().copyWith(supportedTargets: <WallpaperTarget>{WallpaperTarget.home}));

    await pumpScreen(tester);

    expect(find.text('Home screen'), findsOneWidget);
    expect(find.text('Lock screen'), findsNothing);
    expect(find.text('Both'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('APPLY TO lists every target when the device supports them all', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Home screen'), findsOneWidget);
    expect(find.text('Lock screen'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the battery tip keeps its text and copies the steps', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        return null;
      },
    );
    when(() => autoRotateBloc.state).thenReturn(_proState().copyWith(showBatteryTip: true));

    await pumpScreen(tester);

    expect(
      find.text(
        'If wallpapers stop changing, set battery use for Prism to Unrestricted. '
        'Open settings, then Apps, Prism, Battery.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Copy steps'));
    await tester.pump();

    expect(copied, contains('Apps, Prism, Battery'));
    expect(find.text('Steps copied.'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a Pro lapse shows one calm toast and is acknowledged', (tester) async {
    final List<MethodCall> toastCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        toastCalls.add(call);
        return true;
      },
    );
    final StreamController<AutoRotateState> states = StreamController<AutoRotateState>.broadcast();
    addTearDown(states.close);
    whenListen(autoRotateBloc, states.stream, initialState: _proState());
    when(() => sessionBloc.state).thenReturn(
      const SessionState(
        status: LoadStatus.success,
        session: SessionEntity(userId: 'u', loggedIn: true, premium: false, subscriptionTier: 'free'),
      ),
    );

    await pumpScreen(tester);
    states.add(_proState().copyWith(proLapsed: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final Iterable<MethodCall> shown = toastCalls.where((call) => call.method == 'showToast');
    expect(shown, hasLength(1));
    expect(
      (shown.single.arguments as Map<Object?, Object?>)['msg'],
      'Auto-rotate is off because your Prism Pro plan ended.',
    );
    verify(() => autoRotateBloc.add(const AutoRotateEvent.proLapseAcknowledged())).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

AutoRotateState _proState() => AutoRotateState.initial().copyWith(loaded: true, isPro: true, favouriteCount: 5);
