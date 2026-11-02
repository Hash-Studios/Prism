import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/wait_for_real_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('prism-picture-cache-');
  });

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    directory.deleteSync(recursive: true);
  });

  File jpeg(String name) =>
      File('${directory.path}/$name.jpg')..writeAsBytesSync(File('assets/images/wallpaper.jpg').readAsBytesSync());

  testWidgets('a real ResizeImage(FileImage) miss returns null and its cached decode is synchronous', (tester) async {
    final ImageProvider provider = ResizeImage(FileImage(jpeg('uncached')), width: 400);
    final cache = tester.binding.imageCache;

    expect(decodedAspectRatio(provider), isNull);
    expect(cache.pendingImageCount, 1);
    await waitForRealIo(
      tester,
      () => cache.pendingImageCount == 0 && cache.currentSize == 1,
      reason: 'the probe-only local image decode',
    );

    expect(decodedAspectRatio(provider), closeTo(0.5, 0.001));
    expect(decodedAspectRatio(provider), closeTo(0.5, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('probe-only missing and corrupt files are evicted without reporting an image error', (tester) async {
    final File missing = File('${directory.path}/missing.jpg');
    final File corrupt = File('${directory.path}/corrupt.jpg')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final cache = tester.binding.imageCache;
    for (final File file in <File>[missing, corrupt]) {
      final ImageProvider provider = ResizeImage(FileImage(file), width: 400);
      expect(decodedAspectRatio(provider), isNull);
      expect(cache.pendingImageCount, 1);
      // No Image widget/errorBuilder can hide an error from the helper's own resolve.
      await waitForRealIo(
        tester,
        () => cache.pendingImageCount == 0 && cache.liveImageCount == 0,
        reason: 'the failed probe decode and scheduled cache eviction for ${file.path}',
      );
      expect(cache.currentSize, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('repeated cached probes dispose their clones but keep the displayed image drawable', (tester) async {
    final ImageProvider provider = ResizeImage(FileImage(jpeg('handles')), width: 400);
    await tester.pumpWidget(MaterialApp(home: Image(image: provider)));
    await waitForRealIo(
      tester,
      () => tester.widget<RawImage>(find.byType(RawImage)).image != null,
      reason: 'the displayed local image',
    );
    final ui.Image displayed = tester.widget<RawImage>(find.byType(RawImage)).image!;
    final ui.Image retained = displayed.clone();
    addTearDown(() {
      if (!retained.debugDisposed) retained.dispose();
    });
    final int openHandles = retained.debugGetOpenHandleStackTraces()!.length;

    for (var i = 0; i < 100; i++) {
      expect(decodedAspectRatio(provider), closeTo(0.5, 0.001));
      expect(retained.debugGetOpenHandleStackTraces(), hasLength(openHandles));
      expect(displayed.debugDisposed, isFalse);
    }
    // A draw asserts if a probe has disposed the widget's handle or its underlying image.
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImage(displayed, Offset.zero, Paint());
    recorder.endRecording().dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await provider.evict();
    tester.binding.imageCache.clearLiveImages();
    await tester.pump();
    expect(retained.debugGetOpenHandleStackTraces(), hasLength(1));
    expect(retained.debugDisposed, isFalse);
    final bytes = await tester.runAsync(retained.toByteData);
    expect(bytes, isNotNull);
    retained.dispose();
    expect(retained.debugDisposed, isTrue);
    expect(retained.debugGetOpenHandleStackTraces(), isEmpty);
  });

  testWidgets('the cached tile hint matches the full JPEG decode after EXIF rotation', (tester) async {
    final File original = jpeg('original');
    final originalBytes = original.readAsBytesSync();
    // APP1 EXIF with a little-endian TIFF IFD: orientation (0x0112), SHORT, value 6 (90 degrees clockwise).
    const List<int> exif = <int>[
      0xff,
      0xe1,
      0x00,
      0x22,
      0x45,
      0x78,
      0x69,
      0x66,
      0x00,
      0x00,
      0x49,
      0x49,
      0x2a,
      0x00,
      0x08,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x12,
      0x01,
      0x03,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x06,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ];
    final File rotated = File('${directory.path}/rotated.jpg')
      ..writeAsBytesSync(<int>[...originalBytes.take(2), ...exif, ...originalBytes.skip(2)]);
    final List<ImageProvider> providers = <ImageProvider>[
      FileImage(original),
      ResizeImage(FileImage(rotated), width: 400),
      FileImage(rotated),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: providers.map((provider) => Expanded(child: Image(image: provider))).toList(),
        ),
      ),
    );
    await waitForRealIo(
      tester,
      () => tester.widgetList<RawImage>(find.byType(RawImage)).every((image) => image.image != null),
      reason: 'the original, resized rotated tile, and full rotated card decodes',
    );
    final List<ui.Image> images = tester.widgetList<RawImage>(find.byType(RawImage)).map((raw) => raw.image!).toList();
    final double originalRatio = images[0].width / images[0].height;
    final double tileRatio = images[1].width / images[1].height;
    final double cardRatio = images[2].width / images[2].height;

    expect(originalRatio, closeTo(0.5, 0.001));
    expect(cardRatio, closeTo(1 / originalRatio, 0.001));
    expect(tileRatio, closeTo(cardRatio, 0.001));
    expect(decodedAspectRatio(providers[1]), closeTo(cardRatio, 0.001));
    expect(tester.takeException(), isNull);
  });
}
