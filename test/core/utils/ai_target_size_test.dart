import 'dart:ui';

import 'package:Prism/core/utils/ai_target_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a tall phone is limited to the long edge cap', () {
    expect(aiTargetSize(size: const Size(412, 915), devicePixelRatio: 2.625), '920x2048');
  });

  test('a small phone stays above the minimum edge', () {
    expect(aiTargetSize(size: const Size(360, 640), devicePixelRatio: 1), '720x1280');
  });

  test('a tablet is limited to the pixel budget and rounded to multiples of 8', () {
    expect(aiTargetSize(size: const Size(820, 1180), devicePixelRatio: 2), '1424x2040');
  });

  test('a landscape screen gives a landscape size', () {
    expect(aiTargetSize(size: const Size(915, 412), devicePixelRatio: 2.625), '2048x920');
  });
}
