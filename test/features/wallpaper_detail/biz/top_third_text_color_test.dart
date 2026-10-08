import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/biz/top_third_text_color.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 30 px tall image: [top] fills the top third, [rest] the other two thirds.
Future<ui.Image> _split(Color top, Color rest) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 32, 10), Paint()..color = top);
  canvas.drawRect(const Rect.fromLTWH(0, 10, 32, 20), Paint()..color = rest);
  return recorder.endRecording().toImage(32, 30);
}

void main() {
  testWidgets('a bright top third gets black text', (tester) async {
    await tester.runAsync(() async {
      final ui.Image image = await _split(const Color(0xFFF5F5F5), const Color(0xFF000000));
      expect(await textColorForTopThird(image), const Color(0xFF000000));
      image.dispose();
    });
  });

  testWidgets('a dark top third gets white text even when the rest is bright', (tester) async {
    await tester.runAsync(() async {
      final ui.Image image = await _split(const Color(0xFF101820), const Color(0xFFFFFFFF));
      expect(await textColorForTopThird(image), const Color(0xFFFFFFFF));
      image.dispose();
    });
  });

  testWidgets('a mid tone picks the side with more contrast', (tester) async {
    await tester.runAsync(() async {
      final ui.Image image = await _split(const Color(0xFFE57697), const Color(0xFF000000));
      expect(await textColorForTopThird(image), const Color(0xFF000000));
      image.dispose();
    });
  });
}
