import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/biz/wallpaper_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('returns null when the image cannot be decoded', (tester) async {
    final ColorScheme? scheme = await tester.runAsync<ColorScheme?>(
      () => wallpaperScheme(MemoryImage(Uint8List.fromList(<int>[0, 1, 2, 3]))),
    );

    expect(scheme, isNull);
  });

  testWidgets('reads a scheme from a real image', (tester) async {
    final ColorScheme? scheme = await tester.runAsync<ColorScheme?>(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = const Color(0xFFFF0000));
      final ui.Image image = await recorder.endRecording().toImage(4, 4);
      final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return wallpaperScheme(MemoryImage(data.buffer.asUint8List()));
    });

    expect(scheme, isNotNull);
    expect(scheme!.primary.r, greaterThan(scheme.primary.b));
  });
}
