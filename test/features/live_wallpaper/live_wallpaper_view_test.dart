import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_screens.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_wallpaper_view.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/spatial_tilt_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/profile_user_fixture.dart';
import 'fake_live_wallpaper_repository.dart';

class _MockLiveWallpaperBloc extends MockBloc<LiveWallpaperEvent, LiveWallpaperState> implements LiveWallpaperBloc {}

class _MockSessionRepository extends Mock implements SessionRepository {}

/// A device that can show the per-screen choice, on gradients with the Aurora style, unless told otherwise.
LiveWallpaperState _readyState({
  LiveCapabilities capabilities = const LiveCapabilities(
    supportsShaders: true,
    supportsVideo: true,
    supportsPerScreen: true,
  ),
  bool isPro = false,
  GradientStyle gradientStyle = GradientStyle.aurora,
  WallpaperTarget target = WallpaperTarget.home,
  LiveApplyOutcome? outcome,
}) => LiveWallpaperState.initial().copyWith(
  status: LiveWallpaperStatus.ready,
  capabilities: capabilities,
  isPro: isPro,
  gradientStyle: gradientStyle,
  target: target,
  outcome: outcome,
);

/// Pumps the view over a [MockBloc]. [states] are emitted after the first build, as the bloc would.
Future<_MockLiveWallpaperBloc> _pumpScreen(
  WidgetTester tester, {
  required LiveWallpaperState state,
  Stream<LiveWallpaperState>? states,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final _MockLiveWallpaperBloc bloc = _MockLiveWallpaperBloc();
  whenListen(bloc, states ?? const Stream<LiveWallpaperState>.empty(), initialState: state);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: BlocProvider<LiveWallpaperBloc>.value(value: bloc, child: const LiveWallpaperView()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return bloc;
}

void main() {
  late FakeLiveWallpaperRepository repository;
  late LiveWallpaperBloc bloc;

  Future<void> pump(
    WidgetTester tester, {
    String? imageUrl,
    String? depthMapUrl,
    bool isPro = false,
    VideoPicker? pickVideo,
    Color? accentSeed,
  }) async {
    bloc = LiveWallpaperBloc(repository, imageUrl: imageUrl, depthMapUrl: depthMapUrl)
      ..add(LiveWallpaperEvent.started(isPro: isPro));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<LiveWallpaperBloc>.value(
          value: bloc,
          child: pickVideo == null
              ? LiveWallpaperView(imageUrl: imageUrl, accentSeed: accentSeed, depthMapUrl: depthMapUrl)
              : LiveWallpaperView(
                  imageUrl: imageUrl,
                  accentSeed: accentSeed,
                  depthMapUrl: depthMapUrl,
                  pickVideo: pickVideo,
                ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  setUp(() {
    app_state.prismUser = profileUser();
    repository = FakeLiveWallpaperRepository();
  });
  tearDown(() async {
    await getIt.reset();
    app_state.prismUser = profileUser(loggedIn: false);
  });

  testWidgets('shows a clear empty state when the device cannot do live wallpapers', (tester) async {
    repository.capabilities = LiveCapabilities.none;
    await pump(tester);
    expect(find.text('Live wallpapers are not available'), findsOneWidget);
    expect(find.text('Set live wallpaper'), findsNothing);
  });

  testWidgets('without a photo it opens on gradients and hides Make it live', (tester) async {
    await pump(tester);
    expect(find.text('Make it live'), findsNothing);
    expect(find.text('Gradients'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Aurora'), findsOneWidget);
    expect(find.text('Battery saver'), findsOneWidget);
    expect(find.text('30 frames per second'), findsOneWidget);
  });

  testWidgets('the 3D style is hidden for a wall without a depth map', (tester) async {
    await pump(tester, imageUrl: 'https://example.com/a.jpg');
    expect(find.text('3D'), findsNothing);
  });

  testWidgets('the 3D style is offered for a wall with a depth map', (tester) async {
    await pump(tester, imageUrl: 'https://example.com/a.jpg', depthMapUrl: 'https://example.com/map.png');
    expect(find.text('3D'), findsOneWidget);
  });

  testWidgets('switching between Drift and 3D keeps the full photo URL', (tester) async {
    const String imageUrl = 'https://example.com/a.jpg';
    const String mapUrl = 'https://example.com/map.png';
    await pump(tester, imageUrl: imageUrl, depthMapUrl: mapUrl);

    ProgressiveWallpaperImage progressiveImage() =>
        tester.widget<ProgressiveWallpaperImage>(find.byType(ProgressiveWallpaperImage));

    expect(progressiveImage().display.full, imageUrl);

    await tester.ensureVisible(find.text('3D'));
    await tester.tap(find.text('3D'));
    await tester.pump();
    await tester.pump();

    final SpatialTiltView spatialView = tester.widget<SpatialTiltView>(find.byType(SpatialTiltView));
    expect(spatialView.image, isA<CachedNetworkImageProvider>().having((provider) => provider.url, 'url', imageUrl));
    expect(spatialView.mapUrl, mapUrl);

    await tester.ensureVisible(find.text('Drift'));
    await tester.tap(find.text('Drift'));
    await tester.pump();
    await tester.pump();

    expect(progressiveImage().display.full, imageUrl);
    expect(find.byType(SpatialTiltView), findsNothing);
  });

  testWidgets('the 3D preview reads a downloaded photo from its file', (tester) async {
    const String imagePath = '/data/user/0/com.hash.prism/files/a.jpg';
    await pump(tester, imageUrl: imagePath, depthMapUrl: 'https://example.com/map.png');

    await tester.ensureVisible(find.text('3D'));
    await tester.tap(find.text('3D'));
    await tester.pump();
    await tester.pump();

    final SpatialTiltView spatialView = tester.widget<SpatialTiltView>(find.byType(SpatialTiltView));
    expect(spatialView.image, isA<FileImage>().having((provider) => provider.file.path, 'path', imagePath));
  });

  testWidgets('battery saver switches to 15 frames per second', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('15 frames per second'), findsOneWidget);
    expect(bloc.state.batterySaver, isTrue);
  });

  testWidgets('a free user sees Pro styles locked and the button asks to unlock', (tester) async {
    await pump(tester);
    expect(find.text('Set live wallpaper'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));
    await tester.tap(find.text('Starfield'));
    await tester.pump();
    expect(find.text('Unlock · 20 coins'), findsOneWidget);
  });

  testWidgets('a Pro user sees no locks', (tester) async {
    await pump(tester, isPro: true);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    await tester.tap(find.text('Starfield'));
    await tester.pump();
    expect(find.text('Set live wallpaper'), findsOneWidget);
  });

  testWidgets('applying a free gradient reaches the repository and tells the user to confirm', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(repository.gradientApplies, hasLength(1));
    expect(find.text('Confirm in the system preview.'), findsOneWidget);
  });

  testWidgets('a failure shows its message', (tester) async {
    repository.outcome = const LiveApplyOutcome.failed(LiveApplyFailure.setFailed);
    await pump(tester);
    await tester.tap(find.text('Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't set the live wallpaper. Try again."), findsOneWidget);
  });

  group('haptics', () {
    List<String> record(WidgetTester tester) {
      const MethodChannel channel = MethodChannel('prism/haptics');
      PrismHaptics.enabled = true;
      final List<String> events = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'play') events.add(call.arguments! as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      return events;
    }

    testWidgets('a mode chip plays one selection, and Set plays one tap, then the outcome', (tester) async {
      final List<String> haptics = record(tester);
      await pump(tester);
      await tester.tap(find.text('Video'));
      await tester.pump();
      await tester.tap(find.text('Gradients'));
      await tester.pump();
      expect(haptics, <String>['selection', 'selection']);
      haptics.clear();
      await tester.tap(find.text('Set live wallpaper'));
      await tester.pump();
      await tester.pump();
      expect(haptics, <String>['tap']);
    });

    testWidgets('a failed apply plays one error', (tester) async {
      repository.outcome = const LiveApplyOutcome.failed(LiveApplyFailure.setFailed);
      final List<String> haptics = record(tester);
      await pump(tester);
      await tester.tap(find.text('Set live wallpaper'));
      await tester.pump();
      await tester.pump();
      expect(haptics, <String>['tap', 'error']);
    });
  });

  testWidgets('a repeated failure shows its message again after the first one is dismissed', (tester) async {
    repository.outcome = const LiveApplyOutcome.failed(LiveApplyFailure.setFailed);
    await pump(tester);
    await tester.tap(find.text('Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't set the live wallpaper. Try again."), findsOneWidget);

    // The toast dismisses itself.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Couldn't set the live wallpaper. Try again."), findsNothing);

    await tester.tap(find.text('Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't set the live wallpaper. Try again."), findsOneWidget);
  });

  testWidgets('video needs a pick before it can be set, and then applies it', (tester) async {
    await pump(tester, pickVideo: () async => '/tmp/loop.mp4');
    await tester.tap(find.text('Video'));
    await tester.pump();
    PrismButton button() => tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Set live wallpaper'));
    expect(button().onPressed, isNull);

    await tester.tap(find.text('Choose a video'));
    await tester.pump();
    await tester.pump();
    expect(find.text('loop.mp4'), findsOneWidget);
    expect(button().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(PrismButton, 'Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(repository.videoApplies, <String>['/tmp/loop.mp4']);
  });

  testWidgets('a rejected video shows the reason and keeps the button off', (tester) async {
    repository.videoProblem = LiveApplyFailure.videoTooLarge;
    await pump(tester, pickVideo: () async => '/tmp/big.mp4');
    await tester.tap(find.text('Video'));
    await tester.pump();
    await tester.tap(find.text('Choose a video'));
    await tester.pump();
    await tester.pump();
    expect(find.text('That video is larger than 256 MB. Pick a shorter clip.'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Set live wallpaper')).onPressed, isNull);
  });
  group('gradient colours', () {
    const Color seed = Color(0xFF2E9E6B);

    void expectPalette(LivePalette actual, Color accent) {
      final LivePalette expected = LivePalette.fromAccent(accent, dark: false);
      expect(actual.colors, expected.colors);
      expect(actual.background, expected.background);
    }

    Future<void> applyGradient(WidgetTester tester) async {
      await tester.tap(find.text('Set live wallpaper'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('start from the colour of the wallpaper the user came from', (tester) async {
      await pump(tester, accentSeed: seed);
      await applyGradient(tester);

      expectPalette(repository.gradientPalettes.single, seed);
    });

    testWidgets('start from the app accent when there is no wallpaper colour', (tester) async {
      await pump(tester);
      final Color primary = Theme.of(tester.element(find.byType(LiveWallpaperView))).colorScheme.primary;
      await applyGradient(tester);

      expectPalette(repository.gradientPalettes.single, primary);
    });

    testWidgets('show the seed and three variants, and the picked swatch drives the gradient', (tester) async {
      await pump(tester, accentSeed: seed);

      final Finder swatches = find.bySemanticsLabel(RegExp(r'^Gradient colour \d of 4$'));
      expect(swatches, findsNWidgets(4));

      await tester.ensureVisible(find.bySemanticsLabel('Gradient colour 3 of 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Gradient colour 3 of 4'));
      await tester.pump();
      await applyGradient(tester);

      expectPalette(repository.gradientPalettes.single, LivePalette.seedVariants(seed)[2]);
    });

    test('the variants keep the seed first and differ from it', () {
      final List<Color> variants = LivePalette.seedVariants(seed);

      expect(variants, hasLength(4));
      expect(variants.first, seed);
      expect(variants.toSet(), hasLength(4));
    });

    testWidgets('the Make it live tab also uses the wallpaper colour', (tester) async {
      await pump(tester, imageUrl: 'https://example.com/a.jpg', accentSeed: seed);

      expect(find.text('Make it live'), findsOneWidget);
      await tester.tap(find.text('Gradients'));
      await tester.pump();
      await applyGradient(tester);

      expectPalette(repository.gradientPalettes.single, seed);
    });
  });

  group('per-screen choice', () {
    testWidgets('per-screen on shows Home, Lock, Both before Apply', (tester) async {
      final _MockLiveWallpaperBloc bloc = await _pumpScreen(tester, state: _readyState());

      expect(find.bySemanticsLabel('Where to set it'), findsOneWidget);
      expect(find.byType(PrismSegmented<WallpaperTarget>), findsOneWidget);
      expect(find.text('Home screen'), findsOneWidget);
      expect(find.text('Lock screen'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);

      await tester.tap(find.text('Lock screen'));
      await tester.pump();
      verify(() => bloc.add(const LiveWallpaperEvent.targetSelected(WallpaperTarget.lock))).called(1);
    });

    testWidgets('per-screen off looks the same as master', (tester) async {
      await _pumpScreen(
        tester,
        state: _readyState(capabilities: const LiveCapabilities(supportsShaders: true, supportsVideo: true)),
      );

      expect(find.byType(PrismSegmented<WallpaperTarget>), findsNothing);
      expect(find.text('Where to set it'), findsNothing);
      expect(find.text('Home screen'), findsNothing);
      expect(find.text('Lock screen'), findsNothing);
      expect(find.text('Both'), findsNothing);

      expect(find.byType(PrismButton), findsOneWidget);
      expect(find.widgetWithText(PrismButton, 'Set live wallpaper'), findsOneWidget);
      expect(find.text('Android opens a preview. Tap Set wallpaper there.'), findsOneWidget);
      expect(find.text('Gradients'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.byType(PrismCard), findsNothing);
    });

    testWidgets('video mode hides the screen choice', (tester) async {
      await _pumpScreen(tester, state: _readyState());

      await tester.tap(find.text('Video'));
      await tester.pump();

      expect(find.byType(PrismSegmented<WallpaperTarget>), findsNothing);
      expect(find.bySemanticsLabel('Where to set it'), findsNothing);
      expect(find.text('Home screen'), findsNothing);
    });

    testWidgets('second-screen offer after Lock got the wall', (tester) async {
      const LiveScreens screens = LiveScreens(
        home: LiveScreenContent(
          showsPrism: true,
          tag: LiveContentTag(style: GradientStyle.aurora, applyId: 'a'),
        ),
        lock: LiveScreenContent(
          showsPrism: true,
          tag: LiveContentTag(style: MotionStyle.ripple, applyId: 'b'),
        ),
      );
      const LiveApplyOutcome outcome = LiveApplyOutcome.screensSet(target: WallpaperTarget.lock, screens: screens);
      final _MockLiveWallpaperBloc bloc = await _pumpScreen(
        tester,
        state: _readyState(),
        states: Stream<LiveWallpaperState>.value(_readyState(outcome: outcome)),
      );
      await tester.pump();

      expect(find.text('Home screen: Aurora. Lock screen: Ripple.'), findsOneWidget);
      expect(find.text('Pick a wall for the Home screen'), findsOneWidget);
      expect(find.text('Pick a wall for the Lock screen'), findsNothing);

      await tester.tap(find.text('Pick a wall for the Home screen'));
      await tester.pump();
      verify(() => bloc.add(const LiveWallpaperEvent.otherScreenPicked(WallpaperTarget.home))).called(1);
    });

    testWidgets('a both-screens apply offers no second-screen button', (tester) async {
      const LiveScreens screens = LiveScreens(
        home: LiveScreenContent(
          showsPrism: true,
          tag: LiveContentTag(style: GradientStyle.aurora, applyId: 'a'),
        ),
        lock: LiveScreenContent(
          showsPrism: true,
          tag: LiveContentTag(style: GradientStyle.aurora, applyId: 'a'),
        ),
      );
      const LiveApplyOutcome outcome = LiveApplyOutcome.screensSet(target: WallpaperTarget.both, screens: screens);
      await _pumpScreen(
        tester,
        state: _readyState(),
        states: Stream<LiveWallpaperState>.value(_readyState(outcome: outcome)),
      );
      await tester.pump();

      expect(find.text('Home screen: Aurora. Lock screen: Aurora.'), findsOneWidget);
      expect(find.text('Pick a wall for the Home screen'), findsNothing);
      expect(find.text('Pick a wall for the Lock screen'), findsNothing);
    });

    testWidgets('switching to video hides the previous per-screen result and offer', (tester) async {
      const LiveApplyOutcome outcome = LiveApplyOutcome.screensSet(
        target: WallpaperTarget.lock,
        screens: LiveScreens(
          home: LiveScreenContent.other,
          lock: LiveScreenContent(
            showsPrism: true,
            tag: LiveContentTag(style: GradientStyle.aurora, applyId: 'a'),
          ),
        ),
      );
      await _pumpScreen(
        tester,
        state: _readyState(),
        states: Stream<LiveWallpaperState>.value(_readyState(outcome: outcome)),
      );
      expect(find.text('Pick a wall for the Home screen'), findsOneWidget);

      await tester.tap(find.text('Video'));
      await tester.pump();

      expect(find.byType(PrismCard), findsNothing);
      expect(find.text('Pick a wall for the Home screen'), findsNothing);
      expect(find.byType(PrismSegmented<WallpaperTarget>), findsNothing);
      expect(find.text('Choose a video'), findsOneWidget);
    });

    for (final bool signedOut in <bool>[false, true]) {
      testWidgets('resume clears a previous account result after ${signedOut ? 'sign-out' : 'account switch'}', (
        tester,
      ) async {
        const LiveApplyOutcome outcome = LiveApplyOutcome.screensSet(
          target: WallpaperTarget.lock,
          screens: LiveScreens(
            home: LiveScreenContent.other,
            lock: LiveScreenContent(
              showsPrism: true,
              tag: LiveContentTag(style: GradientStyle.aurora, applyId: 'a'),
            ),
          ),
        );
        final _MockLiveWallpaperBloc bloc = await _pumpScreen(
          tester,
          state: _readyState(),
          states: Stream<LiveWallpaperState>.value(_readyState(outcome: outcome)),
        );
        expect(find.text('Pick a wall for the Home screen'), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        app_state.prismUser = profileUser(id: signedOut ? 'u1' : 'u2', loggedIn: !signedOut);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();

        expect(find.byType(PrismCard), findsNothing);
        verifyNever(() => bloc.add(const LiveWallpaperEvent.otherScreenPicked(WallpaperTarget.home)));
      });
    }

    testWidgets('signing back into the same account clears a previous session result', (tester) async {
      final users = StreamController<PrismUsersV2>.broadcast(sync: true);
      addTearDown(users.close);
      final sessions = _MockSessionRepository();
      when(() => sessions.currentUser).thenReturn(profileUser());
      when(() => sessions.watchCurrentUser()).thenAnswer((_) => users.stream);
      getIt.registerSingleton<SessionRepository>(sessions);
      const LiveApplyOutcome outcome = LiveApplyOutcome.screensSet(
        target: WallpaperTarget.lock,
        screens: LiveScreens(
          home: LiveScreenContent.other,
          lock: LiveScreenContent(
            showsPrism: true,
            tag: LiveContentTag(style: GradientStyle.aurora, applyId: 'a'),
          ),
        ),
      );
      await _pumpScreen(
        tester,
        state: _readyState(),
        states: Stream<LiveWallpaperState>.value(_readyState(outcome: outcome)),
      );
      expect(find.text('Pick a wall for the Home screen'), findsOneWidget);

      users.add(profileUser(username: 'updated'));
      await tester.pump();
      expect(find.text('Pick a wall for the Home screen'), findsOneWidget);

      users.add(profileUser(loggedIn: false));
      users.add(profileUser());
      await tester.pump();

      expect(find.byType(PrismCard), findsNothing);
    });

    testWidgets('fallback says both screens get the same wall', (tester) async {
      const LiveApplyOutcome outcome = LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.home, fallback: true);
      await _pumpScreen(
        tester,
        state: _readyState(),
        states: Stream<LiveWallpaperState>.value(_readyState(outcome: outcome)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Confirm in the system preview. This phone shows the same live wall on both screens.'),
        findsOneWidget,
      );
    });

    testWidgets('without per-screen capability the preview message stays the master message', (tester) async {
      const LiveCapabilities capabilities = LiveCapabilities(supportsShaders: true, supportsVideo: true);
      const LiveApplyOutcome outcome = LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.home);
      await _pumpScreen(
        tester,
        state: _readyState(capabilities: capabilities),
        states: Stream<LiveWallpaperState>.value(_readyState(capabilities: capabilities, outcome: outcome)),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Confirm in the system preview.'), findsOneWidget);
      expect(find.text('In the preview, tap Set wallpaper, then Home screen.'), findsNothing);
    });

    testWidgets('large text keeps the result and other-screen offer reachable on a small phone', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const LiveApplyOutcome outcome = LiveApplyOutcome.screensSet(
        target: WallpaperTarget.lock,
        screens: LiveScreens(
          home: LiveScreenContent.other,
          lock: LiveScreenContent(
            showsPrism: true,
            tag: LiveContentTag(style: GradientStyle.aurora, applyId: 'a'),
          ),
        ),
      );
      final _MockLiveWallpaperBloc bloc = await _pumpScreen(
        tester,
        state: _readyState(),
        states: Stream<LiveWallpaperState>.value(_readyState(outcome: outcome)),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      final Finder offer = find.text('Pick a wall for the Home screen');
      await tester.ensureVisible(offer);
      await tester.tap(offer);
      await tester.pump();

      verify(() => bloc.add(const LiveWallpaperEvent.otherScreenPicked(WallpaperTarget.home))).called(1);
    });

    testWidgets('per-screen hint names the picked screen', (tester) async {
      const LiveApplyOutcome outcome = LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.lock);
      await _pumpScreen(
        tester,
        state: _readyState(),
        states: Stream<LiveWallpaperState>.value(_readyState(outcome: outcome)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('In the preview, tap Set wallpaper, then Lock screen.'), findsOneWidget);
    });

    testWidgets('resume reads the screens', (tester) async {
      final _MockLiveWallpaperBloc bloc = await _pumpScreen(tester, state: _readyState());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(() => bloc.add(const LiveWallpaperEvent.screensChecked())).called(1);
    });

    testWidgets('large text keeps the choice usable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpScreen(tester, state: _readyState(), textScaler: const TextScaler.linear(2.0));

      expect(tester.takeException(), isNull);
      for (final String label in <String>['Home screen', 'Lock screen', 'Both']) {
        expect(find.text(label), findsOneWidget);
        final Finder segment = find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first;
        final Size size = tester.getSize(segment);
        expect(size.width, greaterThanOrEqualTo(44), reason: label);
        expect(size.height, greaterThanOrEqualTo(44), reason: label);
      }
    });

    testWidgets('access rules unchanged: a locked style still asks to unlock, with the choice shown', (tester) async {
      await _pumpScreen(tester, state: _readyState(gradientStyle: GradientStyle.starfield));

      expect(find.widgetWithText(PrismButton, 'Unlock · 20 coins'), findsOneWidget);
      expect(find.text('Set live wallpaper'), findsNothing);
      expect(find.byType(PrismSegmented<WallpaperTarget>), findsOneWidget);
      expect(find.text('Home screen'), findsOneWidget);
    });
  });
}
