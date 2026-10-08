import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/theme/contrast.dart';

/// Black or white text, whichever reads on the top third of [image], where the clock sits.
/// Pass a small decode, about 32 px wide: the colour is the average of its top rows.
Future<ui.Color> textColorForTopThird(ui.Image image) async {
  final ByteData? data = await image.toByteData();
  if (data == null || image.width == 0 || image.height == 0) return const ui.Color(0xFFFFFFFF);
  final int rows = (image.height / 3).ceil().clamp(1, image.height);
  double red = 0;
  double green = 0;
  double blue = 0;
  final int pixels = rows * image.width;
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < image.width; x++) {
      final int offset = (y * image.width + x) * 4;
      red += data.getUint8(offset);
      green += data.getUint8(offset + 1);
      blue += data.getUint8(offset + 2);
    }
  }
  return onColor(ui.Color.fromARGB(255, (red / pixels).round(), (green / pixels).round(), (blue / pixels).round()));
}
