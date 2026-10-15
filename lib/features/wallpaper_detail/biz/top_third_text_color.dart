import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/theme/contrast.dart';

/// Black or white text, whichever reads on the top third of [image], where the clock sits.
/// Pass a small decode, about 32 px wide: the colour is the average of its top rows.
///
/// With a [tint] the top third is measured as the preview shows it, under a hue blend of that colour.
Future<ui.Color> textColorForTopThird(ui.Image image, {ui.Color? tint}) async {
  final ui.Image shown = tint == null ? image : await _withHue(image, tint);
  try {
    return await _readableOn(shown);
  } finally {
    if (!identical(shown, image)) shown.dispose();
  }
}

Future<ui.Image> _withHue(ui.Image image, ui.Color tint) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Paint paint = ui.Paint()..colorFilter = ui.ColorFilter.mode(tint, ui.BlendMode.hue);
  ui.Canvas(recorder).drawImage(image, ui.Offset.zero, paint);
  final ui.Picture picture = recorder.endRecording();
  try {
    return await picture.toImage(image.width, image.height);
  } finally {
    picture.dispose();
  }
}

Future<ui.Color> _readableOn(ui.Image image) async {
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
