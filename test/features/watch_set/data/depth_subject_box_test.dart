import 'dart:typed_data';

import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/watch_set/data/depth_subject_box.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List rgbaMap(int width, int height, int Function(int x, int y) value) {
  final Uint8List map = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int i = (y * width + x) * 4;
      final int v = value(x, y);
      map[i] = v;
      map[i + 1] = v;
      map[i + 2] = v;
      map[i + 3] = 255;
    }
  }
  return map;
}

void main() {
  test('a flat depth map has no subject', () {
    final Uint8List map = rgbaMap(10, 10, (int x, int y) => 128);
    expect(subjectBoxFromDepth(map, 10, 10, sourceWidth: 100, sourceHeight: 200), isNull);
  });

  test('a depth map with a spread under 24 levels has no subject', () {
    final Uint8List map = rgbaMap(10, 10, (int x, int y) => x < 5 ? 100 : 110);
    expect(subjectBoxFromDepth(map, 10, 10, sourceWidth: 100, sourceHeight: 200), isNull);
  });

  test('a bright block on a dark background gives its box in source pixels', () {
    final Uint8List map = rgbaMap(10, 10, (int x, int y) => x >= 2 && x <= 4 && y >= 6 && y <= 8 ? 255 : 0);
    expect(subjectBoxFromDepth(map, 10, 10, sourceWidth: 100, sourceHeight: 200), const PixelRect(20, 120, 30, 60));
  });

  test('two bright blocks in the nearest quarter of the range are both in the box', () {
    final Uint8List map = rgbaMap(10, 10, (int x, int y) {
      if (x >= 8 && y >= 8) return 255;
      if (x <= 1 && y <= 1) return 200;
      return 0;
    });
    expect(subjectBoxFromDepth(map, 10, 10, sourceWidth: 10, sourceHeight: 10), const PixelRect(0, 0, 10, 10));
  });

  test('a map shorter than width by height by 4 has no subject', () {
    final Uint8List map = Uint8List(10 * 10 * 4 - 1);
    expect(subjectBoxFromDepth(map, 10, 10, sourceWidth: 100, sourceHeight: 200), isNull);
  });
}
