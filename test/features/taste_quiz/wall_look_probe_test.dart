import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/taste_quiz/data/wall_look_probe.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _png(ui.Color color) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint()..color = color);
  final ui.Image image = await recorder.endRecording().toImage(8, 8);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('a black image measures dark', (tester) async {
    await tester.runAsync(() async {
      final Uint8List png = await _png(const ui.Color(0xFF000000));
      final look = await measureWallLook('u', bytesOf: (_) async => png);
      expect(look, isNotNull);
      expect(look!.luma, closeTo(0, 0.01));
    });
  });

  testWidgets('semi-transparent pixels keep their straight RGB values', (tester) async {
    await tester.runAsync(() async {
      final Uint8List png = await _png(const ui.Color(0x80FF0000));
      final look = await measureWallLook('u', bytesOf: (_) async => png);
      expect(look, isNotNull);
      expect(look!.luma, closeTo(0.2126, 0.01));
    });
  });

  testWidgets('missing bytes give null', (tester) async {
    await tester.runAsync(() async {
      expect(await measureWallLook('u', bytesOf: (_) async => null), isNull);
    });
  });

  testWidgets('garbage bytes give null', (tester) async {
    await tester.runAsync(() async {
      expect(await measureWallLook('u', bytesOf: (_) async => Uint8List.fromList(<int>[1, 2, 3, 4])), isNull);
    });
  });
}
