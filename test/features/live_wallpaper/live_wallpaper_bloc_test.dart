import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import 'fake_live_wallpaper_repository.dart';

final DateTime later = DateTime.now().add(const Duration(days: 3));

void main() {
  final LivePalette palette = LivePalette.fromAccent(const Color(0xFFE57697), dark: true);
  late FakeLiveWallpaperRepository repository;

  LiveWallpaperBloc build({String? imageUrl = 'https://example.com/a.jpg', String? depthMapUrl}) =>
      LiveWallpaperBloc(repository, imageUrl: imageUrl, depthMapUrl: depthMapUrl);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  late FakeAppAnalytics analytics;

  setUp(() {
    repository = FakeLiveWallpaperRepository();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

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
}
