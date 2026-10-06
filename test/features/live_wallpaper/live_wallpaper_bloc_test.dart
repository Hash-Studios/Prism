import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_live_wallpaper_repository.dart';

void main() {
  final LivePalette palette = LivePalette.fromAccent(const Color(0xFFE57697), dark: true);
  late FakeLiveWallpaperRepository repository;

  LiveWallpaperBloc build({String? imageUrl = 'https://example.com/a.jpg'}) =>
      LiveWallpaperBloc(repository, imageUrl: imageUrl);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() => repository = FakeLiveWallpaperRepository());

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
      final LiveWallpaperBloc bloc = build()..add(const LiveWallpaperEvent.started(isPro: true));
      for (final MotionStyle style in MotionStyle.values) {
        bloc
          ..add(LiveWallpaperEvent.motionSelected(style))
          ..add(LiveWallpaperEvent.motionApplied(palette: palette, screenAspectRatio: 0.45));
      }
      await settle();
      expect(repository.motionApplies, MotionStyle.values);
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
      repository.videoProblem = 'That video is larger than 256 MB. Pick a shorter clip.';
      final LiveWallpaperBloc bloc = build()
        ..add(const LiveWallpaperEvent.started(isPro: false))
        ..add(const LiveWallpaperEvent.videoPicked('/tmp/big.mp4'));
      await settle();
      expect(bloc.state.videoPath, isNull);
      expect(bloc.state.outcome?.status, LiveApplyStatus.failed);
      expect(bloc.state.outcome?.message, contains('256 MB'));
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
}
