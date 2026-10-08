import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

Future<void> _openPreview(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
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

bool _isDockIcon(Widget widget) =>
    widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName.contains('playstore');

class _MockCacheManager extends Mock implements BaseCacheManager {}

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

  testWidgets('the preview never tints the image', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ClockOverlay(link: File('assets/images/prism.webp').path, file: true)));

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.color, isNull);
    expect(image.colorBlendMode, isNull);
    expect(find.byType(ColorFiltered), findsNothing);
  });

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

  group('clock text colour', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('clock_overlay_test_'));
    tearDown(() => directory.deleteSync(recursive: true));

    Future<Color?> clockColor(WidgetTester tester, Color wall) async {
      final File file = (await tester.runAsync(() => _solidPng(directory, wall)))!;
      await tester.pumpWidget(MaterialApp(home: ClockOverlay(link: file.path, file: true)));
      await tester.tap(find.text('Lock'));
      await _settleImages(tester);
      return tester.widget<Text>(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$'))).style?.color;
    }

    testWidgets('is white over a dark wall', (tester) async {
      expect(await clockColor(tester, const Color(0xFF0A0A12)), Colors.white);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('is black over a bright wall', (tester) async {
      expect(await clockColor(tester, const Color(0xFFF2F2F2)), Colors.black);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
