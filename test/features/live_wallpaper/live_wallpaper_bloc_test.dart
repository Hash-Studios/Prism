import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_screens.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import 'fake_live_wallpaper_repository.dart';

final DateTime later = DateTime.now().add(const Duration(days: 3));

class _MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  final LivePalette palette = LivePalette.fromAccent(const Color(0xFFE57697), dark: true);
  late FakeLiveWallpaperRepository repository;

  LiveWallpaperBloc build({String? imageUrl = 'https://example.com/a.jpg', String? depthMapUrl}) =>
      LiveWallpaperBloc(repository, imageUrl: imageUrl, depthMapUrl: depthMapUrl);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  late FakeAppAnalytics analytics;

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'owner'
      ..loggedIn = true;
    repository = FakeLiveWallpaperRepository();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  group('started', () {
    test('becomes ready when the device supports live wallpapers', () async {
      final LiveWallpaperBloc bloc = build()..add(const LiveWallpaperEvent.started(isPro: true));
      await settle();
      expect(bloc.state.status, LiveWallpaperStatus.ready);
      expect(bloc.state.isPro, isTrue);
      await bloc.close();
    });

    test('becomes unsupported when nothing is supported', () async {
      repository.capabilities = LiveCapabilities.none;
      final LiveWallpaperBloc bloc = build()..add(const LiveWallpaperEvent.started(isPro: false));
      await settle();
      expect(bloc.state.status, LiveWallpaperStatus.unsupported);
      await bloc.close();
    });

    test('becomes unsupported when the capability check throws', () async {
      repository.capabilitiesError = StateError('boom');
      final LiveWallpaperBloc bloc = build()..add(const LiveWallpaperEvent.started(isPro: false));
      await settle();
      expect(bloc.state.status, LiveWallpaperStatus.unsupported);
      await bloc.close();
    });
  });

  group('Pro gating', () {
    test('free users can apply the free motion style', () async {
      final LiveWallpaperBloc bloc = build()..add(const LiveWallpaperEvent.started(isPro: false));
      await settle();
      bloc.add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
      await settle();
      expect(repository.motionApplies, <MotionStyle>[MotionStyle.drift]);
      expect(repository.motionUrls, <String>['https://example.com/a.jpg']);
      expect(bloc.state.outcome?.status, LiveApplyStatus.confirmInPreview);
      expect(bloc.state.applying, isFalse);
      await bloc.close();
    });

    test('free users cannot apply a Pro motion style', () async {
      final LiveWallpaperBloc bloc = build()
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(const LiveWallpaperEvent.motionSelected(MotionStyle.ripple))
        ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
      await settle();
      expect(repository.motionApplies, isEmpty);
      expect(bloc.state.outcome?.status, LiveApplyStatus.proRequired);
      await bloc.close();
    });

    test('a handled outcome is cleared so the same outcome can be raised again', () async {
      final LiveWallpaperBloc bloc = build(imageUrl: null)
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(const LiveWallpaperEvent.gradientSelected(GradientStyle.starfield))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();
      expect(bloc.state.outcome?.status, LiveApplyStatus.proRequired);

      bloc.add(const LiveWallpaperEvent.outcomeHandled());
      await settle();
      expect(bloc.state.outcome, isNull);

      bloc.add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();
      expect(bloc.state.outcome?.status, LiveApplyStatus.proRequired);
      await bloc.close();
    });

    test('Pro users can apply every motion style', () async {
      final LiveWallpaperBloc bloc = build(depthMapUrl: 'https://example.com/map.png')
        ..add(const LiveWallpaperEvent.started(isPro: true));
      for (final MotionStyle style in MotionStyle.values) {
        bloc
          ..add(LiveWallpaperEvent.motionSelected(style))
          ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
      }
      await settle();
      expect(repository.motionApplies, MotionStyle.values);
      await bloc.close();
    });

    test('a style unlocked with coins applies without Pro, and only that style', () async {
      final LiveWallpaperBloc bloc = build()
        ..add(LiveWallpaperEvent.started(isPro: false, unlockedStyles: <String, DateTime>{'ripple': later}))
        ..add(const LiveWallpaperEvent.motionSelected(MotionStyle.ripple))
        ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
      await settle();
      expect(repository.motionApplies, <MotionStyle>[MotionStyle.ripple]);

      bloc
        ..add(const LiveWallpaperEvent.outcomeHandled())
        ..add(const LiveWallpaperEvent.motionSelected(MotionStyle.shimmer))
        ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
      await settle();
      expect(repository.motionApplies, <MotionStyle>[MotionStyle.ripple]);
      expect(bloc.state.outcome?.status, LiveApplyStatus.proRequired);
      await bloc.close();
    });

    test('an unlock that has ended locks the style again on the next apply', () async {
      final LiveWallpaperBloc bloc = build()
        ..add(
          LiveWallpaperEvent.started(
            isPro: false,
            unlockedStyles: <String, DateTime>{'ripple': DateTime.now().subtract(const Duration(minutes: 1))},
          ),
        )
        ..add(const LiveWallpaperEvent.motionSelected(MotionStyle.ripple))
        ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
      await settle();
      expect(repository.motionApplies, isEmpty);
      expect(bloc.state.outcome?.status, LiveApplyStatus.proRequired);
      await bloc.close();
    });

    test('unlocking a gradient style after the first refusal lets the next apply through', () async {
      final LiveWallpaperBloc bloc = build(imageUrl: null)
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(const LiveWallpaperEvent.gradientSelected(GradientStyle.waves))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();
      expect(bloc.state.outcome?.status, LiveApplyStatus.proRequired);

      bloc
        ..add(LiveWallpaperEvent.unlockedStylesChanged(<String, DateTime>{'waves': later}))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();
      expect(repository.gradientApplies, <GradientStyle>[GradientStyle.waves]);
      await bloc.close();
    });

    test('free gradients are two styles and the rest need Pro', () {
      expect(GradientStyle.values.where((style) => style.isFree), <GradientStyle>[
        GradientStyle.aurora,
        GradientStyle.mesh,
      ]);
      expect(MotionStyle.values.where((style) => style.isFree), <MotionStyle>[MotionStyle.drift]);
    });

    test('free users cannot apply a Pro gradient but can after upgrading', () async {
      final LiveWallpaperBloc bloc = build(imageUrl: null)
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(const LiveWallpaperEvent.gradientSelected(GradientStyle.starfield))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();
      expect(repository.gradientApplies, isEmpty);
      expect(bloc.state.outcome?.status, LiveApplyStatus.proRequired);

      bloc
        ..add(const LiveWallpaperEvent.proChanged(true))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();
      expect(repository.gradientApplies, <GradientStyle>[GradientStyle.starfield]);
      await bloc.close();
    });

    test('video is free', () async {
      final LiveWallpaperBloc bloc = build()
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(const LiveWallpaperEvent.videoPicked('/tmp/a.mp4'))
        ..add(const LiveWallpaperEvent.videoApplied());
      await settle();
      expect(repository.videoApplies, <String>['/tmp/a.mp4']);
      await bloc.close();
    });
  });

  group('3D style', () {
    test('applies the depth style with the depth map and tilt when the device supports tilt', () async {
      repository.capabilities = const LiveCapabilities(supportsShaders: true, supportsVideo: true, supportsTilt: true);
      final LiveWallpaperBloc bloc = build(depthMapUrl: 'https://example.com/map.png')
        ..add(const LiveWallpaperEvent.started(isPro: true))
        ..add(const LiveWallpaperEvent.motionSelected(MotionStyle.depth))
        ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
      await settle();
      expect(repository.motionApplies, <MotionStyle>[MotionStyle.depth]);
      expect(repository.depthMapUrls, <String?>['https://example.com/map.png']);
      expect(repository.tiltValues, <bool>[true]);
      final LiveWallpaperAppliedEvent applied = analytics.events.whereType<LiveWallpaperAppliedEvent>().single;
      expect(applied.style.wireValue, '3d');
      expect(applied.result, 'confirmInPreview');
      await bloc.close();
    });

    test('without a depth map the depth style is not selected', () async {
      final LiveWallpaperBloc bloc = build()
        ..add(const LiveWallpaperEvent.started(isPro: true))
        ..add(const LiveWallpaperEvent.motionSelected(MotionStyle.depth));
      await settle();
      expect(bloc.state.motionStyle, MotionStyle.drift);
      await bloc.close();
    });
  });

  group('battery saver', () {
    test('is passed to the repository', () async {
      final LiveWallpaperBloc bloc = build(imageUrl: null)
        ..add(const LiveWallpaperEvent.started(isPro: true))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette))
        ..add(const LiveWallpaperEvent.batterySaverChanged(true))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();
      expect(repository.batterySaverValues, <bool>[false, true]);
      await bloc.close();
    });
  });

  group('video', () {
    test('a video the repository rejects is not kept, and the reason is shown', () async {
      repository.videoProblem = LiveApplyFailure.videoTooLarge;
      final LiveWallpaperBloc bloc = build()
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(const LiveWallpaperEvent.videoPicked('/tmp/big.mp4'));
      await settle();
      expect(bloc.state.videoPath, isNull);
      expect(bloc.state.outcome?.status, LiveApplyStatus.failed);
      expect(bloc.state.outcome?.failure, LiveApplyFailure.videoTooLarge);
      await bloc.close();
    });

    test('applying without a video does nothing', () async {
      final LiveWallpaperBloc bloc = build()
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(const LiveWallpaperEvent.videoApplied());
      await settle();
      expect(repository.videoApplies, isEmpty);
      await bloc.close();
    });
  });

  test('a photo apply with no image URL does nothing', () async {
    final LiveWallpaperBloc bloc = build(imageUrl: null)
      ..add(const LiveWallpaperEvent.started(isPro: true))
      ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
    await settle();
    expect(repository.motionApplies, isEmpty);
    await bloc.close();
  });
  group('analytics', () {
    List<(String, String)> applied() => analytics.events
        .whereType<LiveWallpaperAppliedEvent>()
        .map((event) => (event.style.wireValue, event.result))
        .toList(growable: false);

    test('reports the style and the result of a motion, a gradient and a video apply', () async {
      final LiveWallpaperBloc bloc = build()
        ..add(const LiveWallpaperEvent.started(isPro: true))
        ..add(const LiveWallpaperEvent.motionSelected(MotionStyle.ripple))
        ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45))
        ..add(const LiveWallpaperEvent.gradientSelected(GradientStyle.mesh))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette))
        ..add(const LiveWallpaperEvent.videoPicked('/tmp/loop.mp4'))
        ..add(const LiveWallpaperEvent.videoApplied());
      await settle();

      expect(applied(), <(String, String)>[
        ('ripple', 'confirmInPreview'),
        ('mesh', 'confirmInPreview'),
        ('video', 'confirmInPreview'),
      ]);
      await bloc.close();
    });

    test('reports a failed apply', () async {
      repository.outcome = const LiveApplyOutcome.failed(LiveApplyFailure.setFailed);
      final LiveWallpaperBloc bloc = build(imageUrl: null)
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();

      expect(applied(), <(String, String)>[('aurora', 'failed')]);
      await bloc.close();
    });

    test('does not report a Pro style that was never applied', () async {
      final LiveWallpaperBloc bloc = build(imageUrl: null)
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(const LiveWallpaperEvent.gradientSelected(GradientStyle.starfield))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();

      expect(applied(), isEmpty);
      await bloc.close();
    });
  });

  group('per-screen target', () {
    const LiveCapabilities perScreen = LiveCapabilities(
      supportsShaders: true,
      supportsVideo: true,
      supportsPerScreen: true,
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'started with per-screen support targets both screens by default',
      build: () {
        repository.capabilities = perScreen;
        return build();
      },
      act: (bloc) async {
        bloc.add(const LiveWallpaperEvent.started(isPro: true));
        await settle();
      },
      verify: (bloc) => expect(bloc.state.target, WallpaperTarget.both),
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'started without per-screen support targets home even when a next target is kept',
      build: () {
        repository.nextTarget = WallpaperTarget.lock;
        return build();
      },
      act: (bloc) async {
        bloc.add(const LiveWallpaperEvent.started(isPro: true));
        await settle();
      },
      verify: (bloc) => expect(bloc.state.target, WallpaperTarget.home),
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'started takes the next target the user chose and clears it',
      build: () {
        repository.capabilities = perScreen;
        repository.nextTarget = WallpaperTarget.lock;
        return build();
      },
      act: (bloc) async {
        bloc.add(const LiveWallpaperEvent.started(isPro: true));
        await settle();
      },
      verify: (bloc) {
        expect(bloc.state.target, WallpaperTarget.lock);
        expect(repository.nextTarget, isNull);
      },
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'a gradient apply with per-screen support sends the selected target and a fresh tag',
      build: () {
        repository.capabilities = perScreen;
        return build(imageUrl: null);
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(const LiveWallpaperEvent.targetSelected(WallpaperTarget.lock))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        await settle();
      },
      verify: (bloc) {
        expect(repository.lastTarget, WallpaperTarget.lock);
        expect(repository.lastTag?.style, GradientStyle.aurora);
      },
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'without per-screen support a gradient apply always sends home',
      build: () => build(imageUrl: null),
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(const LiveWallpaperEvent.targetSelected(WallpaperTarget.lock))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        await settle();
      },
      verify: (bloc) => expect(repository.lastTarget, WallpaperTarget.home),
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'a non-Pro paid gradient is refused for lock and nothing is applied',
      build: () {
        repository.capabilities = perScreen;
        return build(imageUrl: null);
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: false))
          ..add(const LiveWallpaperEvent.targetSelected(WallpaperTarget.lock))
          ..add(const LiveWallpaperEvent.gradientSelected(GradientStyle.waves))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        await settle();
      },
      verify: (bloc) {
        expect(bloc.state.outcome?.status, LiveApplyStatus.proRequired);
        expect(repository.gradientApplies, isEmpty);
        expect(repository.lastTarget, isNull);
      },
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'a non-Pro paid motion style is refused for lock and nothing is applied',
      build: () {
        repository.capabilities = perScreen;
        return build();
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: false))
          ..add(const LiveWallpaperEvent.targetSelected(WallpaperTarget.lock))
          ..add(const LiveWallpaperEvent.motionSelected(MotionStyle.ripple))
          ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
        await settle();
      },
      verify: (bloc) {
        expect(bloc.state.outcome?.status, LiveApplyStatus.proRequired);
        expect(repository.motionApplies, isEmpty);
        expect(repository.lastTarget, isNull);
      },
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'a confirm-in-preview apply with per-screen support keeps its tag as the pending tag',
      build: () {
        repository.capabilities = perScreen;
        repository.outcome = const LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.lock);
        return build(imageUrl: null);
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(const LiveWallpaperEvent.targetSelected(WallpaperTarget.lock))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        await settle();
      },
      verify: (bloc) {
        expect(repository.lastTag, isNotNull);
        expect(bloc.state.pendingTag, repository.lastTag);
      },
    );

    test('starting a new session clears an apply tag from the previous session', () async {
      repository.capabilities = perScreen;
      final LiveWallpaperBloc bloc = build(imageUrl: null)
        ..add(const LiveWallpaperEvent.started(isPro: true));
      await settle();
      bloc.add(LiveWallpaperEvent.gradientApplied(palette: palette));
      await settle();
      expect(bloc.state.pendingTag, isNotNull);

      bloc.add(const LiveWallpaperEvent.started(isPro: false));
      await settle();

      expect(bloc.state.pendingTag, isNull);
      expect(bloc.state.outcome, isNull);
      await bloc.close();
    });

    for (final bool signOut in <bool>[true, false]) {
      final String identityChange = signOut ? 'signout' : 'account switch';

      void changeAccount() {
        app_state.prismUser = app_constants.createGuestPrismUser();
        if (!signOut) {
          app_state.prismUser
            ..id = 'another-owner'
            ..loggedIn = true;
        }
      }

      test('$identityChange discards a pending preview before reading the screens', () async {
        repository.capabilities = perScreen;
        final LiveWallpaperBloc bloc = build(imageUrl: null)
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        addTearDown(bloc.close);
        await settle();
        expect(bloc.state.pendingTag, isNotNull);
        repository.screens = LiveScreens(
          home: LiveScreenContent(showsPrism: true, tag: repository.lastTag),
          lock: LiveScreenContent.other,
        );

        changeAccount();
        bloc.add(const LiveWallpaperEvent.screensChecked());
        await settle();

        expect(bloc.state.outcome, isNull);
        expect(bloc.state.pendingTag, isNull);
        expect(repository.getScreensCalls, 0);
      });

      test('$identityChange discards a screen response already in flight', () async {
        repository.capabilities = perScreen;
        final LiveWallpaperBloc bloc = build(imageUrl: null)
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        addTearDown(bloc.close);
        await settle();
        repository.screensResult = Completer<LiveScreens>();
        bloc.add(const LiveWallpaperEvent.screensChecked());
        await settle();
        expect(repository.getScreensCalls, 1);

        changeAccount();
        repository.screensResult!.complete(
          LiveScreens(
            home: LiveScreenContent(showsPrism: true, tag: repository.lastTag),
            lock: LiveScreenContent.other,
          ),
        );
        await settle();

        expect(bloc.state.outcome, isNull);
        expect(bloc.state.pendingTag, isNull);
      });

      for (final bool motion in <bool>[true, false]) {
        test('$identityChange discards an in-flight ${motion ? 'motion' : 'gradient'} apply result', () async {
          repository.capabilities = perScreen;
          repository.applyResult = Completer<LiveApplyOutcome>();
          final LiveWallpaperBloc bloc = build()
            ..add(const LiveWallpaperEvent.started(isPro: true))
            ..add(
              motion
                  ? LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45)
                  : LiveWallpaperEvent.gradientApplied(palette: palette),
            );
          addTearDown(bloc.close);
          await settle();
          expect(bloc.state.applying, isTrue);
          expect(repository.lastTag, isNotNull);

          changeAccount();
          repository.applyResult!.complete(const LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.home));
          await settle();

          expect(bloc.state.pendingTag, isNull);
          expect(bloc.state.outcome, isNull);
          expect(bloc.state.applying, isFalse);
        });
      }
    }

    for (final String phase in <String>['pending preview', 'screen response', 'motion apply', 'gradient apply']) {
      test('signing back into the same account discards an old session $phase', () async {
        repository.capabilities = perScreen;
        PrismUsersV2 currentUser = app_state.prismUser;
        final session = _MockSessionRepository();
        final users = StreamController<PrismUsersV2>.broadcast(sync: true);
        addTearDown(users.close);
        when(() => session.currentUser).thenAnswer((_) => currentUser);
        when(() => session.watchCurrentUser()).thenAnswer((_) => users.stream);
        getIt.registerSingleton<SessionRepository>(session);
        if (phase.endsWith('apply')) repository.applyResult = Completer<LiveApplyOutcome>();
        final LiveWallpaperBloc bloc = build()
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(
            phase == 'motion apply'
                ? LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45)
                : LiveWallpaperEvent.gradientApplied(palette: palette),
          );
        addTearDown(bloc.close);
        await settle();
        final screens = LiveScreens(
          home: LiveScreenContent(showsPrism: true, tag: repository.lastTag),
          lock: LiveScreenContent.other,
        );
        if (phase == 'screen response') {
          repository.screensResult = Completer<LiveScreens>();
          bloc.add(const LiveWallpaperEvent.screensChecked());
          await settle();
          expect(repository.getScreensCalls, 1);
        }

        final PrismUsersV2 previousUser = currentUser;
        currentUser = app_constants.createGuestPrismUser();
        users.add(currentUser);
        currentUser = previousUser;
        users.add(currentUser);
        if (phase == 'pending preview') {
          repository.screens = screens;
          bloc.add(const LiveWallpaperEvent.screensChecked());
        } else if (phase == 'screen response') {
          repository.screensResult!.complete(screens);
        } else {
          repository.applyResult!.complete(const LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.home));
        }
        await settle();

        expect(bloc.state.outcome, isNull);
        expect(bloc.state.pendingTag, isNull);
        if (phase == 'pending preview') expect(repository.getScreensCalls, 0);
      });
    }

    test('same-account profile updates keep the pending preview and close releases the session listener', () async {
      repository.capabilities = perScreen;
      PrismUsersV2 currentUser = app_state.prismUser;
      final session = _MockSessionRepository();
      final users = StreamController<PrismUsersV2>.broadcast(sync: true);
      addTearDown(users.close);
      when(() => session.currentUser).thenAnswer((_) => currentUser);
      when(() => session.watchCurrentUser()).thenAnswer((_) => users.stream);
      getIt.registerSingleton<SessionRepository>(session);
      final LiveWallpaperBloc bloc = build(imageUrl: null)
        ..add(const LiveWallpaperEvent.started(isPro: true))
        ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
      addTearDown(bloc.close);
      await settle();
      expect(users.hasListener, isTrue);

      currentUser = app_constants.createGuestPrismUser()
        ..id = 'owner'
        ..loggedIn = true
        ..premium = true;
      users.add(currentUser);
      repository.screens = LiveScreens(
        home: LiveScreenContent(showsPrism: true, tag: repository.lastTag),
        lock: LiveScreenContent.other,
      );
      bloc.add(const LiveWallpaperEvent.screensChecked());
      await settle();

      expect(bloc.state.outcome?.status, LiveApplyStatus.applied);
      await bloc.close();
      expect(users.hasListener, isFalse);
    });

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'a confirm-in-preview apply without per-screen support has no pending tag',
      build: () {
        repository.outcome = const LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.home);
        return build(imageUrl: null);
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        await settle();
      },
      verify: (bloc) => expect(bloc.state.pendingTag, isNull),
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'checking the screens after a preview reports the screens that got the apply',
      build: () {
        repository.capabilities = perScreen;
        repository.outcome = const LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.lock);
        return build(imageUrl: null);
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(const LiveWallpaperEvent.targetSelected(WallpaperTarget.lock))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        await settle();
        repository.screens = LiveScreens(
          home: LiveScreenContent.other,
          lock: LiveScreenContent(showsPrism: true, tag: repository.lastTag),
        );
        bloc.add(const LiveWallpaperEvent.screensChecked());
        await settle();
      },
      verify: (bloc) {
        expect(bloc.state.outcome?.status, LiveApplyStatus.applied);
        expect(bloc.state.outcome?.target, WallpaperTarget.lock);
        expect(bloc.state.outcome?.screens, repository.screens);
        expect(bloc.state.pendingTag, isNull);
      },
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'checking the screens when no screen shows the tag reports no outcome',
      build: () {
        repository.capabilities = perScreen;
        repository.outcome = const LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.lock);
        return build(imageUrl: null);
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(const LiveWallpaperEvent.targetSelected(WallpaperTarget.lock))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        await settle();
        repository.screens = const LiveScreens(
          home: LiveScreenContent(
            showsPrism: true,
            tag: LiveContentTag(style: GradientStyle.mesh, applyId: 'someone-else'),
          ),
          lock: LiveScreenContent.other,
        );
        bloc.add(const LiveWallpaperEvent.screensChecked());
        await settle();
      },
      verify: (bloc) {
        expect(bloc.state.outcome, isNull);
        expect(bloc.state.pendingTag, isNull);
      },
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'checking the screens without a pending apply does not read the screens',
      build: () {
        repository.capabilities = perScreen;
        return build();
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(const LiveWallpaperEvent.screensChecked());
        await settle();
      },
      verify: (bloc) => expect(repository.getScreensCalls, 0),
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'picking another screen selects it and keeps it for the next wall',
      build: () {
        repository.capabilities = perScreen;
        return build();
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(const LiveWallpaperEvent.otherScreenPicked(WallpaperTarget.home));
        await settle();
      },
      verify: (bloc) {
        expect(bloc.state.target, WallpaperTarget.home);
        expect(repository.nextTarget, WallpaperTarget.home);
      },
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'picking a screen in settings does not leave a next-wall target behind',
      build: () {
        repository.capabilities = perScreen;
        return build(imageUrl: null);
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(const LiveWallpaperEvent.otherScreenPicked(WallpaperTarget.lock));
        await settle();
      },
      verify: (bloc) {
        expect(bloc.state.target, WallpaperTarget.lock);
        expect(repository.nextTarget, isNull);
      },
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'a per-screen gradient apply is tracked with its target, per_screen on and no fallback',
      build: () {
        repository.capabilities = perScreen;
        repository.outcome = const LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.lock);
        return build(imageUrl: null);
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(const LiveWallpaperEvent.targetSelected(WallpaperTarget.lock))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        await settle();
      },
      verify: (bloc) {
        final LiveWallpaperAppliedEvent applied = analytics.events.whereType<LiveWallpaperAppliedEvent>().single;
        expect(applied.target, WallpaperTarget.lock);
        expect(applied.perScreen, isTrue);
        expect(applied.fallback, isFalse);
      },
    );

    blocTest<LiveWallpaperBloc, LiveWallpaperState>(
      'a per-screen-off apply that fell back is tracked as home with fallback on',
      build: () {
        repository.outcome = const LiveApplyOutcome.confirmInPreview(target: WallpaperTarget.home, fallback: true);
        return build(imageUrl: null);
      },
      act: (bloc) async {
        bloc
          ..add(const LiveWallpaperEvent.started(isPro: true))
          ..add(LiveWallpaperEvent.gradientApplied(palette: palette));
        await settle();
      },
      verify: (bloc) {
        final LiveWallpaperAppliedEvent applied = analytics.events.whereType<LiveWallpaperAppliedEvent>().single;
        expect(applied.target, WallpaperTarget.home);
        expect(applied.perScreen, isFalse);
        expect(applied.fallback, isTrue);
      },
    );
  });
}
