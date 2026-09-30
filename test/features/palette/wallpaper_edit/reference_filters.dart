import 'dart:math' as math;

typedef Rgb = List<double>;
typedef Step = Rgb Function(Rgb);

Rgb refBrightness(Rgb c, double adj) {
  final double t = (255 * adj.clamp(-1, 1)).roundToDouble();
  return [c[0] + t, c[1] + t, c[2] + t];
}

Rgb refContrast(Rgb c, double adj) {
  final double a = adj * 255;
  final double f = (259 * (a + 255)) / (255 * (259 - a));
  return [for (final double v in c) f * (v - 128) + 128];
}

Rgb refSaturation(Rgb c, double adj) {
  final double s = math.max(-1, adj);
  final double gray = 0.2989 * c[0] + 0.5870 * c[1] + 0.1140 * c[2];
  return [for (final double v in c) -gray * s + v * (1 + s)];
}

Rgb refGrayscale(Rgb c) {
  final double v = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  return [v, v, v];
}

Rgb refSepia(Rgb c, double adj) {
  final double r = c[0];
  final double g = c[1];
  final double b = c[2];
  return [
    r * (1 - 0.607 * adj) + g * 0.769 * adj + b * 0.189 * adj,
    r * 0.349 * adj + g * (1 - 0.314 * adj) + b * 0.168 * adj,
    r * 0.272 * adj + g * 0.534 * adj + b * (1 - 0.869 * adj),
  ];
}

Rgb refInvert(Rgb c) => [for (final double v in c) 255 - v];

Rgb refOverlay(Rgb c, double r, double g, double b, double scale) => [
  c[0] - (c[0] - r) * scale,
  c[1] - (c[1] - g) * scale,
  c[2] - (c[2] - b) * scale,
];

Rgb refRgbScale(Rgb c, double r, double g, double b) => [c[0] * r, c[1] * g, c[2] * b];

Rgb refAdditive(Rgb c, double r, double g, double b) => [c[0] + r, c[1] + g, c[2] + b];

Step brightnessStep(double a) =>
    (c) => refBrightness(c, a);
Step contrastStep(double a) =>
    (c) => refContrast(c, a);
Step saturationStep(double a) =>
    (c) => refSaturation(c, a);
Step sepiaStep(double a) =>
    (c) => refSepia(c, a);
Step grayscaleStep() => refGrayscale;
Step invertStep() => refInvert;
Step overlayStep(double r, double g, double b, double s) =>
    (c) => refOverlay(c, r, g, b, s);
Step rgbScaleStep(double r, double g, double b) =>
    (c) => refRgbScale(c, r, g, b);
Step additiveStep(double r, double g, double b) =>
    (c) => refAdditive(c, r, g, b);

final Map<String, List<Step>> photofiltersRecipes = <String, List<Step>>{
  'AddictiveBlue': [additiveStep(0, 0, 50)],
  'AddictiveRed': [additiveStep(50, 0, 0)],
  'Aden': [overlayStep(228, 130, 225, 0.13), saturationStep(-0.2)],
  'Amaro': [saturationStep(0.3), brightnessStep(0.15)],
  'Ashby': [overlayStep(255, 160, 25, 0.1), brightnessStep(0.1)],
  'Brannan': [contrastStep(0.2), overlayStep(140, 10, 185, 0.1)],
  'Brooklyn': [overlayStep(25, 240, 252, 0.05), sepiaStep(0.3)],
  'Charmes': [overlayStep(255, 50, 80, 0.12), contrastStep(0.05)],
  'Clarendon': [brightnessStep(0.1), contrastStep(0.1), saturationStep(0.15)],
  'Crema': [rgbScaleStep(1.04, 1, 1.02), saturationStep(-0.05)],
  'Dogpatch': [contrastStep(0.15), brightnessStep(0.1)],
  'Earlybird': [overlayStep(255, 165, 40, 0.2), saturationStep(0.15)],
  '1977': [overlayStep(255, 25, 0, 0.15), brightnessStep(0.1)],
  'Gingham': [sepiaStep(0.04), contrastStep(-0.15)],
  'Ginza': [sepiaStep(0.06), brightnessStep(0.1)],
  'Hefe': [contrastStep(0.1), saturationStep(0.15)],
  'Helena': [overlayStep(208, 208, 86, 0.2), contrastStep(0.15)],
  'Hudson': [rgbScaleStep(1, 1, 1.25), contrastStep(0.1), brightnessStep(0.15)],
  'Inkwell': [grayscaleStep()],
  'Invert': [invertStep()],
  'Juno': [rgbScaleStep(1.01, 1.04, 1), saturationStep(0.3)],
  'Kelvin': [overlayStep(255, 140, 0, 0.1), rgbScaleStep(1.15, 1.05, 1), saturationStep(0.35)],
  'Lark': [brightnessStep(0.08), grayscaleStep(), contrastStep(-0.04)],
  'Lo-Fi': [contrastStep(0.15), saturationStep(0.2)],
  'Ludwig': [brightnessStep(0.05), saturationStep(-0.03)],
  'Maven': [overlayStep(225, 240, 0, 0.1), saturationStep(0.25), contrastStep(0.05)],
  'Mayfair': [overlayStep(230, 115, 108, 0.05), saturationStep(0.15)],
  'Moon': [grayscaleStep(), contrastStep(-0.04), brightnessStep(0.1)],
  'Nashville': [overlayStep(220, 115, 188, 0.12), contrastStep(-0.05)],
  'Perpetua': [rgbScaleStep(1.05, 1.1, 1)],
  'Reyes': [sepiaStep(0.4), brightnessStep(0.13), contrastStep(-0.05)],
  'Rise': [overlayStep(255, 170, 0, 0.1), brightnessStep(0.09), saturationStep(0.1)],
  'Sierra': [contrastStep(-0.15), saturationStep(0.1)],
  'Skyline': [saturationStep(0.35), brightnessStep(0.1)],
  'Slumber': [brightnessStep(0.1), saturationStep(-0.5)],
  'Stinson': [brightnessStep(0.1), sepiaStep(0.3)],
  'Sutro': [brightnessStep(-0.1), saturationStep(-0.1)],
  'Toaster': [sepiaStep(0.1), overlayStep(255, 145, 0, 0.2)],
  'Valencia': [overlayStep(255, 225, 80, 0.08), saturationStep(0.1), contrastStep(0.05)],
  'Vesper': [overlayStep(255, 225, 0, 0.05), brightnessStep(0.06), contrastStep(0.06)],
  'Walden': [brightnessStep(0.1), overlayStep(255, 255, 0, 0.2)],
  'Willow': [grayscaleStep(), overlayStep(100, 28, 210, 0.03), brightnessStep(0.1)],
  'X-Pro II': [overlayStep(255, 255, 0, 0.07), saturationStep(0.2), contrastStep(0.15)],
};

Rgb applyMatrix(List<double> m, Rgb rgb) => [
  for (int c = 0; c < 3; c++) m[c * 5] * rgb[0] + m[c * 5 + 1] * rgb[1] + m[c * 5 + 2] * rgb[2] + m[c * 5 + 4],
];
