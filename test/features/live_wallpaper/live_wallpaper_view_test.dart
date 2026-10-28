import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

Future<File> _createKnownPhoto() async {
  final Directory directory = await Directory.systemTemp.createTemp('prism-live-preview-');
  final File file = File('${directory.path}/photo #1.png');
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawColor(const Color(0xFF123456), BlendMode.src);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(2, 3);
  picture.dispose();
  final ByteData bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  await file.writeAsBytes(bytes.buffer.asUint8List());
  return file;
}

Future<void> _waitForImage(WidgetTester tester, ImageProvider provider) async {
  final Finder preview = find.byType(SpatialTiltView);
  final ImageStream stream = provider.resolve(createLocalImageConfiguration(tester.element(preview)));
  final Completer<void> decoded = Completer<void>();
  final ImageStreamListener listener = ImageStreamListener(
    (ImageInfo info, _) {
      if (!decoded.isCompleted) decoded.complete();
      info.dispose();
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!decoded.isCompleted) decoded.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  try {
    for (int frame = 0; frame < 50 && !decoded.isCompleted; frame++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(decoded.isCompleted, isTrue, reason: 'the preview image stream should complete');
    await decoded.future;
  } finally {
    stream.removeListener(listener);
  }
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

  testWidgets('the 3D preview uses a bundled asset for the wallpaper', (tester) async {
    const String imagePath = 'assets/app_icons/icon_default.jpg';
    await pump(tester, imageUrl: imagePath, depthMapUrl: 'https://example.com/map.png');

    await tester.ensureVisible(find.text('3D'));
    await tester.tap(find.text('3D'));
    await tester.pump();
    await tester.pump();

    final SpatialTiltView spatialView = tester.widget<SpatialTiltView>(find.byType(SpatialTiltView));
    expect(spatialView.image, isA<AssetImage>().having((provider) => provider.assetName, 'assetName', imagePath));

    await _waitForImage(tester, spatialView.image);
    await tester.pump();
    final RawImage rawImage = tester.widget<RawImage>(
      find.descendant(of: find.byType(SpatialTiltView), matching: find.byType(RawImage)).first,
    );
    expect(rawImage.image, isNotNull, reason: 'the bundled wallpaper should decode in the 3D preview');
    expect((rawImage.image!.width, rawImage.image!.height), (512, 512));
    final ByteData pixels = (await tester.runAsync(() async => (await rawImage.image!.toByteData())!))!;
    expect(pixels.lengthInBytes, 512 * 512 * 4);
  });

  testWidgets('an encoded file URI keeps spaces and hashes in the local wallpaper path', (tester) async {
    final File photo = (await tester.runAsync(_createKnownPhoto))!;
    addTearDown(() async {
      if (await photo.parent.exists()) await photo.parent.delete(recursive: true);
    });
    final String imageUrl = photo.uri.toString();
    expect(imageUrl, contains('%20'));
    expect(imageUrl, contains('%23'));
    await pump(tester, imageUrl: imageUrl, depthMapUrl: 'https://example.com/map.png');

    await tester.ensureVisible(find.text('3D'));
    await tester.tap(find.text('3D'));
    await tester.pump();
    await tester.pump();

    final SpatialTiltView spatialView = tester.widget<SpatialTiltView>(find.byType(SpatialTiltView));
    expect(spatialView.image, isA<FileImage>().having((provider) => provider.file.path, 'path', photo.path));
    await _waitForImage(tester, spatialView.image);
    await tester.pump();

    final RawImage rawImage = tester.widget<RawImage>(
      find.descendant(of: find.byType(SpatialTiltView), matching: find.byType(RawImage)).first,
    );
    expect(rawImage.image, isNotNull, reason: 'the downloaded photo should decode in the live preview');
    expect((rawImage.image!.width, rawImage.image!.height), (2, 3));
    final ByteData pixels = (await tester.runAsync(() async => (await rawImage.image!.toByteData())!))!;
    expect((pixels.getUint8(0), pixels.getUint8(1), pixels.getUint8(2), pixels.getUint8(3)), (0x12, 0x34, 0x56, 0xFF));
  });

  testWidgets('an empty or whitespace-only photo URL starts in gradients and hides the photo mode', (tester) async {
    final List<String> imageUrls = <String>['', '   ', '\n\t'];
    for (int index = 0; index < imageUrls.length; index++) {
      await tester.pumpWidget(const SizedBox.shrink());
      final String imageUrl = imageUrls[index];
      await pump(tester, imageUrl: imageUrl);

      expect(find.text('Make it live'), findsNothing, reason: 'URL should be absent: ${imageUrl.trim().isEmpty}');
      expect(find.text('Gradients'), findsOneWidget);
      expect(find.text('Set live wallpaper'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Set live wallpaper')).onPressed, isNotNull);

      await tester.tap(find.text('Set live wallpaper'));
      await tester.pump();
      await tester.pump();
      expect(repository.gradientApplies, hasLength(index + 1));
      expect(repository.motionApplies, isEmpty);
    }
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
