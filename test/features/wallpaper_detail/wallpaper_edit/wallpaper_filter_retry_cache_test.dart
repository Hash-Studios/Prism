import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/wait_for_real_io.dart';

Future<Uint8List> _png(Color color) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 1001, 1999), Paint()..color = color);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(1001, 1999);
  try {
    final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Finder _previewImage() => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is GestureDetector && widget.onLongPressStart != null),
  matching: find.byType(Image),
);

Future<void> _waitUntilReady(WidgetTester tester) => waitForRealIo(tester, () {
  final Finder button = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
  return button.evaluate().isNotEmpty && tester.widget<IconButton>(button).onPressed != null;
}, reason: 'editor source loaded');

Future<List<int>> _firstPixel(ui.Image image) async {
  final ByteData data = (await image.toByteData())!;
  return data.buffer.asUint8List().take(4).toList();
}

void main() {
  testWidgets('retry reads fresh pixels instead of a previously cached resize of the same file', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    final Directory directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('wallpaper_filter_retry_cache_'),
    ))!;
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    await tester.runAsync(() async => source.writeAsBytes(await _png(const Color(0xFFFF0000))));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperFilterScreen(filePath: source.path),
      ),
    );
    await _waitUntilReady(tester);
    await tester.pumpAndSettle();
    final ui.Image initialImage = tester
        .widget<RawImage>(find.descendant(of: _previewImage(), matching: find.byType(RawImage)))
        .image!;
    expect(await tester.runAsync(() => _firstPixel(initialImage)), <int>[255, 0, 0, 255]);

    // Keep the successful initial resize cached, but force the landscape preview to request another resize.
    await tester.runAsync(() => source.writeAsBytes(<int>[0, 1, 2, 3]));
    await tester.tap(find.text('Crop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('16:9 desktop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await waitForRealIo(tester, () => find.text('Try again').evaluate().isNotEmpty, reason: 'uncached resize fails');

    await tester.runAsync(() async => source.writeAsBytes(await _png(const Color(0xFF0000FF))));
    await tester.tap(find.text('Try again'));
    await _waitUntilReady(tester);
    await tester.pumpAndSettle();

    final ui.Image retriedImage = tester
        .widget<RawImage>(find.descendant(of: _previewImage(), matching: find.byType(RawImage)))
        .image!;
    final List<int> previewPixel = (await tester.runAsync(() => _firstPixel(retriedImage)))!;
    final List<int> exportPixel = (await tester.runAsync(() async {
      final Uint8List exported = await renderEditedFile(
        source.path,
        stack: const <WallpaperFilter>[],
        adjustments: WallpaperAdjustments.none,
      );
      final ui.Codec codec = await ui.instantiateImageCodec(exported);
      try {
        final ui.Image image = (await codec.getNextFrame()).image;
        try {
          return await _firstPixel(image);
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    }))!;
    expect(exportPixel, <int>[0, 0, 255, 255]);
    expect(
      previewPixel,
      exportPixel,
      reason: 'Retry must discard successful old resizes too, not just change the Image widget key.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
