import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_wallpaper_view.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/spatial_tilt_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_live_wallpaper_repository.dart';

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

  setUp(() => repository = FakeLiveWallpaperRepository());

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

  testWidgets('a repeated failure shows its message again after the first one is dismissed', (tester) async {
    repository.outcome = const LiveApplyOutcome.failed(LiveApplyFailure.setFailed);
    await pump(tester);
    await tester.tap(find.text('Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't set the live wallpaper. Try again."), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(LiveWallpaperView))).hideCurrentSnackBar();
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
    FilledButton button() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Set live wallpaper'));
    expect(button().onPressed, isNull);

    await tester.tap(find.text('Choose a video'));
    await tester.pump();
    await tester.pump();
    expect(find.text('loop.mp4'), findsOneWidget);
    expect(button().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Set live wallpaper'));
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
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Set live wallpaper')).onPressed, isNull);
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
}
