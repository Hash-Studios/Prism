import 'dart:ui';

import 'package:Prism/core/wallpaper/duo_reveal_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical canvas and folded crop match the literal Prism preset', () {
    expect(DuoRevealGeometry.canvas, const Size(2670, 1878));
    final Rect crop = DuoRevealGeometry.folded;
    expect(crop.left, closeTo(1379.221238938053, 1e-9));
    expect(crop.width, closeTo(1290.778761061947, 1e-9));
    expect(crop.top, 0);
    expect(crop.height, 1878);
    expect(crop.right, 2670);
  });

  test('portrait input center-covers before taking the right-source crop', () {
    final Rect whole = DuoRevealGeometry.sourceRect(const Size(1000, 2000), unfolded: true);
    expect(whole.left, 0);
    expect(whole.top, closeTo(648.314606741573, 1e-9));
    expect(whole.width, 1000);
    expect(whole.height, closeTo(703.370786516854, 1e-9));
    final Rect folded = DuoRevealGeometry.sourceRect(const Size(1000, 2000), unfolded: false);
    expect(folded.left, closeTo(516.562261774552, 1e-9));
    expect(folded.right, 1000);
    expect(folded.top, whole.top);
    expect(folded.height, whole.height);
    expect(folded.width / folded.height, closeTo(1398 / 2034, 1e-12));
  });

  test('ultrawide input discards the margins before cropping', () {
    final Rect whole = DuoRevealGeometry.sourceRect(const Size(6000, 2000), unfolded: true);
    expect(whole.top, 0);
    expect(whole.height, 2000);
    expect(whole.left, closeTo(1578.2747603833866, 1e-9));
    final Rect folded = DuoRevealGeometry.sourceRect(const Size(6000, 2000), unfolded: false);
    expect(folded.right, closeTo(4421.725239616613, 1e-9));
    expect(folded.width / folded.height, closeTo(1398 / 2034, 1e-12));
  });
}
