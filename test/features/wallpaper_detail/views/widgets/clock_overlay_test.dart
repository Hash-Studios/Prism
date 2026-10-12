import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:cached_network_image/cached_network_image.dart';
// ignore: depend_on_referenced_packages
import 'package:file/file.dart' as pkg_file;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

Widget _withMedia(BuildContext context, Widget? child, EdgeInsets safeArea, bool reduceMotion, double textScale) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: safeArea,
      viewPadding: safeArea,
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  );
}

Future<void> _openPreview(
  WidgetTester tester, {
  EdgeInsets safeArea = EdgeInsets.zero,
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => _withMedia(context, child, safeArea, reduceMotion, textScale),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ClockOverlay(link: File('assets/images/prism.webp').path, file: true),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

bool _isLockDate(Widget widget) => widget is Text && widget.style?.fontFamily == 'CupertinoSystemText';

bool _isDockIcon(Widget widget) =>
    widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName.contains('playstore');

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockFile extends Mock implements pkg_file.File {}

Future<File> _solidPng(Directory directory, Color color) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 80), Paint()..color = color);
  final ui.Image image = await recorder.endRecording().toImage(40, 80);
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final File file = File('${directory.path}/${color.toARGB32()}.png');
  await file.writeAsBytes(data.buffer.asUint8List());
  image.dispose();
  return file;
}

/// Image files load on the real event loop, so alternate real waits with frames.
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

Future<Color> _pixelAt(WidgetTester tester, RenderRepaintBoundary boundary, Offset point) async {
  final ui.Image shot = (await tester.runAsync(boundary.toImage))!;
  final ByteData data = (await tester.runAsync(() async => (await shot.toByteData())!))!;
  final int offset = (point.dy.round() * shot.width + point.dx.round()) * 4;
  final Color pixel = Color.fromARGB(255, data.getUint8(offset), data.getUint8(offset + 1), data.getUint8(offset + 2));
  shot.dispose();
  return pixel;
}

void main() {
  test('ordinal suffix uses th for 11 to 13', () {
    expect(<int>[1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31].map(ordinalSuffix).toList(), <String>[
      'ˢᵗ',
      'ⁿᵈ',
      'ʳᵈ',
      'ᵗʰ',
      'ᵗʰ',
      'ᵗʰ',
      'ᵗʰ',
      'ˢᵗ',
      'ⁿᵈ',
      'ʳᵈ',
      'ˢᵗ',
    ]);
  });

  testWidgets('iOS previews a lock screen without the Android dock', (WidgetTester tester) async {
    await _openPreview(tester);

    expect(find.byWidgetPredicate(_isDockIcon), findsNothing);
    expect(find.textContaining('27°C'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android keeps the launcher preview', (WidgetTester tester) async {
    await _openPreview(tester);

    expect(find.byWidgetPredicate(_isDockIcon), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the preview closes from a labelled button', (WidgetTester tester) async {
    await _openPreview(tester);

    await tester.tap(find.bySemanticsLabel('Close preview'));
    await tester.pumpAndSettle();

    expect(find.byType(ClockOverlay), findsNothing);
  });

  testWidgets('without a tint the image is shown as it is', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ClockOverlay(link: File('assets/images/prism.webp').path, file: true)));

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.color, isNull);
    expect(image.colorBlendMode, isNull);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('a tint puts a hue filter of that colour over the image', (tester) async {
    const Color tint = Color(0xFF3366CC);
    await tester.pumpWidget(
      MaterialApp(
        home: ClockOverlay(link: File('assets/images/prism.webp').path, file: true, tint: tint),
      ),
    );

    expect(
      tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
      const ColorFilter.mode(tint, BlendMode.hue),
    );
    expect(find.descendant(of: find.byType(ColorFiltered), matching: find.byType(Image)), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('the time follows the 12 or 24 hour setting', () {
    final afternoon = DateTime(2026, 1, 5, 15, 7);

    expect(formatClockTime(afternoon, use24Hour: false), '3:07');
    expect(formatClockTime(afternoon, use24Hour: true), '15:07');
  });

  testWidgets('the Android lock view shows the device time style and no dock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: ClockOverlay(link: File('assets/images/prism.webp').path, file: true),
        ),
      ),
    );

    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate(_isDockIcon), findsNothing);
    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the Home toggle hides the big clock on iOS', (tester) async {
    await _openPreview(tester);
    expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('image loading', () {
    late _MockCacheManager cache;

    setUp(() {
      cache = _MockCacheManager();
      PrismFullImageCache.testOverride = cache;
      when(
        () => cache.getFileStream(any(), withProgress: any(named: 'withProgress')),
      ).thenAnswer((_) => Stream<FileResponse>.error(const SocketException('offline')));
    });

    tearDown(() => PrismFullImageCache.testOverride = null);

    testWidgets('the full image uses the full-size cache and a screen-width decode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClockOverlay(link: 'https://img.test/full.jpg', file: false, thumbnailUrl: 'https://img.test/t.jpg'),
        ),
      );

      final CachedNetworkImage image = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).first;
      expect(image.cacheManager, same(cache));
      expect(image.memCacheWidth, isNotNull);
      expect(image.memCacheWidth, lessThanOrEqualTo(2160));
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a failed load shows a message icon instead of an empty screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ClockOverlay(link: 'https://img.test/full.jpg', file: false)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a missing local file shows the same fallback', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ClockOverlay(link: '/nonexistent/wall.png', file: true)));
      await _settleImages(tester);

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('tint pixels', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('clock_overlay_pixels_'));
    tearDown(() => directory.deleteSync(recursive: true));

    Future<Color> centrePixel(WidgetTester tester, {Color? tint}) async {
      final File file = (await tester.runAsync(() => _solidPng(directory, const Color(0xFFCC3333))))!;
      final GlobalKey boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: ClockOverlay(link: file.path, file: true, tint: tint),
          ),
        ),
      );
      await _settleImages(tester);
      final ui.Image shot = (await tester.runAsync(
        () => (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(),
      ))!;
      final ByteData data = (await tester.runAsync(() async => (await shot.toByteData())!))!;
      final int offset = ((shot.height ~/ 2) * shot.width + shot.width ~/ 2) * 4;
      final Color pixel = Color.fromARGB(
        255,
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      );
      shot.dispose();
      return pixel;
    }

    testWidgets('a blue tint turns a red wall blue and no tint leaves it red', (tester) async {
      final Color plain = await centrePixel(tester);
      expect(plain.r, greaterThan(plain.b));

      final Color tinted = await centrePixel(tester, tint: const Color(0xFF2255EE));
      expect(tinted.b, greaterThan(tinted.r));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('tint on a network image', () {
    const Color tint = Color(0xFF3366CC);
    late Directory directory;
    late _MockCacheManager fullCache;
    late _MockCacheManager thumbnailCache;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('clock_overlay_tint_');
      fullCache = _MockCacheManager();
      thumbnailCache = _MockCacheManager();
      PrismFullImageCache.testOverride = fullCache;
      PrismImageCache.testOverride = thumbnailCache;
    });

    tearDown(() {
      PrismFullImageCache.testOverride = null;
      PrismImageCache.testOverride = null;
      directory.deleteSync(recursive: true);
    });

    void serve(_MockCacheManager cache, Uint8List? bytes) {
      final _MockFile file = _MockFile();
      if (bytes != null) when(() => file.readAsBytes()).thenAnswer((_) async => bytes);
      when(() => cache.getFileStream(any(), withProgress: any(named: 'withProgress'))).thenAnswer(
        (_) => bytes == null
            ? StreamController<FileResponse>().stream
            : Stream<FileResponse>.value(
                FileInfo(file, FileSource.Cache, DateTime.now().add(const Duration(days: 1)), 'https://img.test/x'),
              ),
      );
    }

    Future<void> pumpTinted(WidgetTester tester, {required bool fullLoads, required bool thumbnailLoads}) async {
      final File png = (await tester.runAsync(() => _solidPng(directory, const Color(0xFFCC3333))))!;
      final Uint8List bytes = (await tester.runAsync(png.readAsBytes))!;
      serve(fullCache, fullLoads ? bytes : null);
      serve(thumbnailCache, thumbnailLoads ? bytes : null);
      await tester.pumpWidget(
        const MaterialApp(
          home: ClockOverlay(
            link: 'https://img.test/full.jpg',
            file: false,
            thumbnailUrl: 'https://img.test/t.jpg',
            tint: tint,
          ),
        ),
      );
      await _settleImages(tester);
    }

    testWidgets('covers the full image', (tester) async {
      await pumpTinted(tester, fullLoads: true, thumbnailLoads: false);

      expect(
        tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
        const ColorFilter.mode(tint, BlendMode.hue),
      );
      expect(find.descendant(of: find.byType(ColorFiltered), matching: find.byType(Image)), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('covers the thumbnail while the full image loads', (tester) async {
      await pumpTinted(tester, fullLoads: false, thumbnailLoads: true);

      expect(
        tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
        const ColorFilter.mode(tint, BlendMode.hue),
      );
      expect(find.descendant(of: find.byType(ColorFiltered), matching: find.byType(Image)), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('status bar and framing', () {
    const EdgeInsets deviceInsets = EdgeInsets.only(top: 40, bottom: 34);

    testWidgets('the iOS lock date starts 24 below the status bar', (tester) async {
      await _openPreview(tester, safeArea: deviceInsets);

      expect(tester.getTopLeft(find.byWidgetPredicate(_isLockDate)).dy, 64);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the Android lock clock sits below the status bar', (tester) async {
      await _openPreview(tester, safeArea: deviceInsets);
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$'))).dy, greaterThan(40));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the Android dock stays above the Lock and Home pill', (tester) async {
      await _openPreview(tester, safeArea: deviceInsets);

      final Finder dock = find.descendant(of: find.byType(HomePreviewLayer), matching: find.byType(Row));
      expect(tester.getBottomLeft(dock).dy, lessThan(tester.getTopLeft(find.byType(PrismGlass)).dy));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the image fills the screen from the top left whatever the safe area', (tester) async {
      await _openPreview(tester, safeArea: deviceInsets);

      expect(tester.getRect(find.byType(Image).first), const Rect.fromLTWH(0, 0, 800, 600));
    });
  });

  group('Lock and Home toggle', () {
    Finder indicator() =>
        find.descendant(of: find.byType(AnimatedPositionedDirectional), matching: find.byType(DecoratedBox));

    double layerOpacity(WidgetTester tester, Type layer) => tester
        .widget<FadeTransition>(find.ancestor(of: find.byType(layer), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;

    Color labelColor(WidgetTester tester, String label) => tester
        .widget<DefaultTextStyle>(find.ancestor(of: find.text(label), matching: find.byType(DefaultTextStyle)).first)
        .style
        .color!;

    double pillWidth(WidgetTester tester) => tester.getSize(find.byType(PrismGlass)).width;

    testWidgets('a tap swaps the layer and never closes the preview', (tester) async {
      await _openPreview(tester);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePreviewLayer), findsOneWidget);
      expect(find.byType(LockPreviewLayer), findsNothing);
      expect(find.byType(ClockOverlay), findsOneWidget);

      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();
      expect(find.byType(LockPreviewLayer), findsOneWidget);
      expect(find.byType(HomePreviewLayer), findsNothing);
      expect(find.byType(ClockOverlay), findsOneWidget);

      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();
      expect(find.byType(LockPreviewLayer), findsOneWidget);
      expect(find.byType(ClockOverlay), findsOneWidget);
    }, variant: TargetPlatformVariant.all());

    testWidgets('the two layers cross-fade for 160 ms and then only the new one is left', (tester) async {
      await _openPreview(tester);

      await tester.tap(find.text('Lock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byType(HomePreviewLayer), findsOneWidget);
      expect(find.byType(LockPreviewLayer), findsOneWidget);
      expect(layerOpacity(tester, LockPreviewLayer), inExclusiveRange(0, 1));
      expect(layerOpacity(tester, HomePreviewLayer), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HomePreviewLayer), findsNothing);
      expect(layerOpacity(tester, LockPreviewLayer), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the layers swap without a fade when the system asks for less motion', (tester) async {
      await _openPreview(tester, reduceMotion: true);

      await tester.tap(find.text('Lock'));
      await tester.pump();

      expect(find.byType(HomePreviewLayer), findsNothing);
      expect(find.byType(LockPreviewLayer), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the selected segment is announced as selected', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openPreview(tester);

      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Lock')),
        isSemantics(label: 'Lock', isButton: true, isInMutuallyExclusiveGroup: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home')),
        isSemantics(label: 'Home', isButton: true, isInMutuallyExclusiveGroup: true, isSelected: false),
      );
      handle.dispose();
    });

    testWidgets('the indicator slides to the tapped segment in 180 ms and covers most of the way by half time', (
      tester,
    ) async {
      await _openPreview(tester);
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();
      final double lockX = tester.getCenter(indicator()).dx;

      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final double midX = tester.getCenter(indicator()).dx;
      await tester.pump(const Duration(milliseconds: 90));
      final double homeX = tester.getCenter(indicator()).dx;
      await tester.pumpAndSettle();

      expect(homeX - lockX, pillWidth(tester) / 2);
      expect(tester.getCenter(indicator()).dx, homeX);
      expect((midX - lockX) / (homeX - lockX), inExclusiveRange(0.9, 1));
    });

    testWidgets('the indicator jumps when the system asks for less motion', (tester) async {
      await _openPreview(tester, reduceMotion: true);
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();
      final double lockX = tester.getCenter(indicator()).dx;

      await tester.tap(find.text('Home'));
      await tester.pump();

      expect(tester.getCenter(indicator()).dx, lockX + pillWidth(tester) / 2);
    });

    testWidgets('the selected label is dark and the other is light', (tester) async {
      await _openPreview(tester);

      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();
      expect(labelColor(tester, 'Lock'), Colors.black87);
      expect(labelColor(tester, 'Home'), Colors.white.withValues(alpha: 0.88));

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(labelColor(tester, 'Home'), Colors.black87);
      expect(labelColor(tester, 'Lock'), Colors.white.withValues(alpha: 0.88));
    });

    testWidgets('the glass is a 60 percent scrim with the thin 16 refraction of a small pill', (tester) async {
      await _openPreview(tester);

      final PrismGlass glass = tester.widget<PrismGlass>(find.byType(PrismGlass));

      expect(glass.thickness, 16);
      expect(glass.glassColor!.a, closeTo(0.6, 0.001));
    });

    testWidgets('the pill is 48 tall, 24 above the bottom safe area, and the whole height taps', (tester) async {
      await _openPreview(tester, safeArea: const EdgeInsets.only(bottom: 34));
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(PrismGlass)).height, 48);
      expect(tester.getBottomLeft(find.byType(PrismGlass)).dy, 600 - 34 - 24);

      await tester.tapAt(tester.getBottomLeft(find.byType(PrismGlass)) + const Offset(20, -2));
      await tester.pumpAndSettle();

      expect(find.byType(LockPreviewLayer), findsOneWidget);
      expect(find.byType(ClockOverlay), findsOneWidget);
    });

    group('text size', () {
      Future<void> openAt(WidgetTester tester, double textScale) async {
        await tester.pumpWidget(const SizedBox());
        await _openPreview(tester, textScale: textScale);
      }

      testWidgets('each segment is at least 84 wide', (tester) async {
        await _openPreview(tester);

        expect(pillWidth(tester), greaterThanOrEqualTo(2 * 84));
      });

      testWidgets('larger text widens the pill, keeps it 48 tall, and stops growing past 1.5x', (tester) async {
        await openAt(tester, 1);
        final double normal = pillWidth(tester);
        await openAt(tester, 1.5);
        final double large = pillWidth(tester);
        await openAt(tester, 2);

        expect(large, greaterThan(normal));
        expect(pillWidth(tester), large);
        expect(tester.getSize(find.byType(PrismGlass)).height, 48);
        expect(tester.renderObject<RenderParagraph>(find.text('Home')).textScaler.scale(10), 15);
      });

      testWidgets('at 2x text both labels sit inside their own half of the pill', (tester) async {
        await openAt(tester, 2);

        final Rect pill = tester.getRect(find.byType(PrismGlass));
        final Rect lock = tester.getRect(find.text('Lock'));
        final Rect home = tester.getRect(find.text('Home'));

        expect(tester.takeException(), isNull);
        expect(lock.left, greaterThan(pill.left));
        expect(lock.right, lessThan(pill.center.dx));
        expect(home.left, greaterThan(pill.center.dx));
        expect(home.right, lessThan(pill.right));
      });
    });
  });

  group('toggle over a bright wall', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('clock_overlay_toggle_'));
    tearDown(() => directory.deleteSync(recursive: true));

    testWidgets('the selected label reads on a solid light indicator', (tester) async {
      final File file = (await tester.runAsync(() => _solidPng(directory, const Color(0xFFFFFFFF))))!;
      final GlobalKey boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: ClockOverlay(link: file.path, file: true),
          ),
        ),
      );
      await tester.tap(find.text('Lock'));
      await _settleImages(tester);
      await tester.pumpAndSettle();

      final Rect indicator = tester.getRect(
        find.descendant(of: find.byType(AnimatedPositionedDirectional), matching: find.byType(DecoratedBox)),
      );
      final Color pixel = await _pixelAt(
        tester,
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary,
        indicator.bottomLeft + const Offset(14, -5),
      );
      final Color label = tester
          .widget<DefaultTextStyle>(find.ancestor(of: find.text('Lock'), matching: find.byType(DefaultTextStyle)).first)
          .style
          .color!;

      expect(contrastRatio(Color.alphaBlend(label, pixel), pixel), greaterThan(7));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the unselected label reads on the glass over a near white wall', (tester) async {
      final File file = (await tester.runAsync(() => _solidPng(directory, const Color(0xFFFAFAFA))))!;
      final GlobalKey boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: ClockOverlay(link: file.path, file: true),
          ),
        ),
      );
      await tester.tap(find.text('Lock'));
      await _settleImages(tester);
      await tester.pumpAndSettle();

      final Rect pill = tester.getRect(find.byType(PrismGlass));
      final Color pixel = await _pixelAt(
        tester,
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary,
        Offset(pill.center.dx + 6, pill.center.dy),
      );
      final Color label = tester
          .widget<DefaultTextStyle>(find.ancestor(of: find.text('Home'), matching: find.byType(DefaultTextStyle)).first)
          .style
          .color!;

      expect(contrastRatio(Color.alphaBlend(label, pixel), pixel), greaterThan(4));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('clock text colour', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('clock_overlay_test_'));
    tearDown(() => directory.deleteSync(recursive: true));

    Future<Color> sampledClockColor(WidgetTester tester, Color wall) async {
      final File file = (await tester.runAsync(() => _solidPng(directory, wall)))!;
      await tester.pumpWidget(MaterialApp(home: ClockOverlay(link: file.path, file: true)));
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();
      final Finder clock = find.textContaining(RegExp(r'^\d{1,2}:\d{2}$'));
      final Color beforeSample = Theme.of(tester.element(clock)).colorScheme.secondary;
      final Stopwatch waited = Stopwatch()..start();
      while (tester.widget<Text>(clock).style!.color == beforeSample && waited.elapsed < const Duration(seconds: 30)) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      return tester.widget<Text>(clock).style!.color!;
    }

    testWidgets('is white over a dark wall', (tester) async {
      expect(await sampledClockColor(tester, const Color(0xFF0A0A12)), Colors.white);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('is black over a bright wall', (tester) async {
      expect(await sampledClockColor(tester, const Color(0xFFF2F2F2)), Colors.black);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
