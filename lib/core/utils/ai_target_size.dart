import 'dart:math';
import 'dart:ui';

const int _minShortEdge = 720;
const int _maxLongEdge = 2048;
const double _maxPixelBudget = 2.9 * 1000 * 1000;

/// Generation size (`WxH`) that matches a screen of [size] logical pixels at [devicePixelRatio].
///
/// Keeps the screen aspect ratio, limits edges to 720..2048 and the area to 2.9 megapixels,
/// and rounds both edges to a multiple of 8.
String aiTargetSize({required Size size, required double devicePixelRatio}) {
  final double dpr = devicePixelRatio.clamp(1.0, 3.0);
  final int rawW = (size.width * dpr).round().clamp(360, 4096);
  final int rawH = (size.height * dpr).round().clamp(640, 4096);

  final bool portrait = rawH >= rawW;
  final int longRaw = portrait ? rawH : rawW;
  final int shortRaw = portrait ? rawW : rawH;
  final double aspect = longRaw / shortRaw;

  int shortTarget = shortRaw.clamp(_minShortEdge, _maxLongEdge);
  int longTarget = (shortTarget * aspect).round();
  if (longTarget > _maxLongEdge) {
    longTarget = _maxLongEdge;
    shortTarget = (longTarget / aspect).round().clamp(_minShortEdge, _maxLongEdge);
  }

  int width = portrait ? shortTarget : longTarget;
  int height = portrait ? longTarget : shortTarget;

  final int pixels = width * height;
  if (pixels > _maxPixelBudget) {
    final double scale = sqrt(_maxPixelBudget / pixels);
    width = (width * scale).round();
    height = (height * scale).round();
  }

  width = ((width / 8).round() * 8).clamp(512, _maxLongEdge);
  height = ((height / 8).round() * 8).clamp(512, _maxLongEdge);
  return '${width}x$height';
}
