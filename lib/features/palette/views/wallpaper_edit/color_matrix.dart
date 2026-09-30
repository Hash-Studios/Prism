import 'dart:math' as math;

/// A 4x5 row-major colour matrix in the layout of `ColorFilter.matrix`.
/// Offsets (indices 4, 9, 14, 19) use the 0..255 range.
typedef ColorMatrix = List<double>;

const ColorMatrix identityMatrix = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

/// Returns the matrix that applies [first] and then [second].
ColorMatrix composeMatrices(ColorMatrix first, ColorMatrix second) {
  final ColorMatrix out = List<double>.filled(20, 0);
  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 5; col++) {
      double sum = col == 4 ? second[row * 5 + 4] : 0;
      for (int k = 0; k < 4; k++) {
        sum += second[row * 5 + k] * first[k * 5 + col];
      }
      out[row * 5 + col] = sum;
    }
  }
  return out;
}

ColorMatrix chainMatrices(Iterable<ColorMatrix> matrices) => matrices.fold(identityMatrix, composeMatrices);

bool isIdentityMatrix(ColorMatrix m) {
  for (int i = 0; i < 20; i++) {
    if ((m[i] - identityMatrix[i]).abs() > 1e-6) return false;
  }
  return true;
}

ColorMatrix _rgb(List<double> r, List<double> g, List<double> b, [double tr = 0, double tg = 0, double tb = 0]) =>
    <double>[r[0], r[1], r[2], 0, tr, g[0], g[1], g[2], 0, tg, b[0], b[1], b[2], 0, tb, 0, 0, 0, 1, 0];

/// `adj` in -1..1, adds `255 * adj` to each channel.
ColorMatrix brightnessMatrix(double adj) {
  final double t = (255 * adj.clamp(-1, 1)).roundToDouble();
  return _rgb(const [1, 0, 0], const [0, 1, 0], const [0, 0, 1], t, t, t);
}

/// `adj` in -1..1, stretches channels around mid grey.
ColorMatrix contrastMatrix(double adj) {
  final double a = adj * 255;
  final double f = (259 * (a + 255)) / (255 * (259 - a));
  final double t = 128 * (1 - f);
  return _rgb([f, 0, 0], [0, f, 0], [0, 0, f], t, t, t);
}

/// `adj` of 0 keeps colour, -1 is grey, positive values boost colour (CCIR 601 weights).
ColorMatrix saturationMatrix(double adj) {
  final double s = math.max(-1, adj);
  const double lr = 0.2989;
  const double lg = 0.5870;
  const double lb = 0.1140;
  return _rgb([1 + s - lr * s, -lg * s, -lb * s], [-lr * s, 1 + s - lg * s, -lb * s], [
    -lr * s,
    -lg * s,
    1 + s - lb * s,
  ]);
}

ColorMatrix grayscaleMatrix() {
  const List<double> row = [0.2126, 0.7152, 0.0722];
  return _rgb(row, row, row);
}

/// `adj` of 0 keeps colour, 1 is full sepia.
ColorMatrix sepiaMatrix(double adj) => _rgb(
  [1 - 0.607 * adj, 0.769 * adj, 0.189 * adj],
  [0.349 * adj, 1 - 0.314 * adj, 0.168 * adj],
  [0.272 * adj, 0.534 * adj, 1 - 0.869 * adj],
);

ColorMatrix rgbScaleMatrix(double r, double g, double b) => _rgb([r, 0, 0], [0, g, 0], [0, 0, b]);

/// Moves each channel `scale` of the way toward the colour (r, g, b).
ColorMatrix overlayMatrix(double r, double g, double b, double scale) {
  final double k = 1 - scale;
  return _rgb([k, 0, 0], [0, k, 0], [0, 0, k], r * scale, g * scale, b * scale);
}

ColorMatrix additiveMatrix(double r, double g, double b) =>
    _rgb(const [1, 0, 0], const [0, 1, 0], const [0, 0, 1], r, g, b);

ColorMatrix invertMatrix() => _rgb(const [-1, 0, 0], const [0, -1, 0], const [0, 0, -1], 255, 255, 255);

/// Rotates hue by [degrees] around the luminance axis.
ColorMatrix hueMatrix(double degrees) {
  final double rad = degrees * math.pi / 180;
  final double c = math.cos(rad);
  final double s = math.sin(rad);
  const double lr = 0.213;
  const double lg = 0.715;
  const double lb = 0.072;
  return _rgb(
    [lr + c * (1 - lr) - s * lr, lg - c * lg - s * lg, lb - c * lb + s * (1 - lb)],
    [lr - c * lr + s * 0.143, lg + c * (1 - lg) + s * 0.140, lb - c * lb - s * 0.283],
    [lr - c * lr - s * (1 - lr), lg - c * lg + s * lg, lb + c * (1 - lb) + s * lb],
  );
}

/// Multiplies every channel by [factor] (1 keeps the image as is).
ColorMatrix exposureMatrix(double factor) => rgbScaleMatrix(factor, factor, factor);
