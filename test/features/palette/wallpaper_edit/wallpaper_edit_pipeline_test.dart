import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/palette/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/palette/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> redImage() {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = const Color(0xFFFF0000));
  return recorder.endRecording().toImage(4, 4);
}

Future<List<int>> centrePixel(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData data = (await image.toByteData())!;
  final int o = (2 * image.width + 2) * 4;
  return [data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ColorPreset invert = colorPresets.firstWhere((p) => p.name == 'Invert');

  test('buildEditFilter returns null for an empty edit', () {
    expect(buildEditFilter(const [], WallpaperAdjustments.none, 100), isNull);
  });

  test('buildEditFilter returns a filter for a preset', () {
    expect(buildEditFilter([invert], WallpaperAdjustments.none, 100), isNotNull);
  });

  test('buildEditFilter returns a filter for blur', () {
    expect(buildEditFilter(const [], const WallpaperAdjustments(blur: 0.5), 100), isNotNull);
  });

  testWidgets('renderEditedPng inverts red to cyan', (tester) async {
    await tester.runAsync(() async {
      final ui.Image image = await redImage();
      final List<int> px = await centrePixel(await renderEditedPng(image, [invert], WallpaperAdjustments.none));
      expect(px[0], inInclusiveRange(0, 2));
      expect(px[1], inInclusiveRange(253, 255));
      expect(px[2], inInclusiveRange(253, 255));
    });
  });

  testWidgets('renderEditedPng with no edit keeps red', (tester) async {
    await tester.runAsync(() async {
      final ui.Image image = await redImage();
      final List<int> px = await centrePixel(await renderEditedPng(image, const [], WallpaperAdjustments.none));
      expect(px[0], inInclusiveRange(253, 255));
      expect(px[1], inInclusiveRange(0, 2));
      expect(px[2], inInclusiveRange(0, 2));
    });
  });

  testWidgets('loadKernelEffects completes', (tester) async {
    await tester.runAsync(() async {
      await expectLater(loadKernelEffects(), completion(isA<bool>()));
    });
  });
}
