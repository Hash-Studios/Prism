import 'package:Prism/features/palette/views/wallpaper_edit/color_matrix.dart';

/// A named look the user can stack on a wallpaper.
sealed class WallpaperFilter {
  const WallpaperFilter(this.name);

  final String name;
}

/// A per-pixel colour change. Stacks by matrix product, so any number of them costs one GPU pass.
class ColorPreset extends WallpaperFilter {
  ColorPreset(super.name, List<ColorMatrix> steps) : matrix = chainMatrices(steps);

  final ColorMatrix matrix;
}

/// A 3x3 convolution run by `shaders/convolve3x3.frag`. Needs Impeller.
class KernelEffect extends WallpaperFilter {
  const KernelEffect(super.name, this.kernel, {this.bias = 0});

  /// Row-major weights, top row first.
  final List<double> kernel;

  /// Added to each channel, 0..255.
  final double bias;
}

final List<ColorPreset> colorPresets = <ColorPreset>[
  ColorPreset('AddictiveBlue', [additiveMatrix(0, 0, 50)]),
  ColorPreset('AddictiveRed', [additiveMatrix(50, 0, 0)]),
  ColorPreset('Aden', [overlayMatrix(228, 130, 225, 0.13), saturationMatrix(-0.2)]),
  ColorPreset('Amaro', [saturationMatrix(0.3), brightnessMatrix(0.15)]),
  ColorPreset('Ashby', [overlayMatrix(255, 160, 25, 0.1), brightnessMatrix(0.1)]),
  ColorPreset('Brannan', [contrastMatrix(0.2), overlayMatrix(140, 10, 185, 0.1)]),
  ColorPreset('Brooklyn', [overlayMatrix(25, 240, 252, 0.05), sepiaMatrix(0.3)]),
  ColorPreset('Charmes', [overlayMatrix(255, 50, 80, 0.12), contrastMatrix(0.05)]),
  ColorPreset('Clarendon', [brightnessMatrix(0.1), contrastMatrix(0.1), saturationMatrix(0.15)]),
  ColorPreset('Crema', [rgbScaleMatrix(1.04, 1, 1.02), saturationMatrix(-0.05)]),
  ColorPreset('Dogpatch', [contrastMatrix(0.15), brightnessMatrix(0.1)]),
  ColorPreset('Earlybird', [overlayMatrix(255, 165, 40, 0.2), saturationMatrix(0.15)]),
  ColorPreset('1977', [overlayMatrix(255, 25, 0, 0.15), brightnessMatrix(0.1)]),
  ColorPreset('Gingham', [sepiaMatrix(0.04), contrastMatrix(-0.15)]),
  ColorPreset('Ginza', [sepiaMatrix(0.06), brightnessMatrix(0.1)]),
  ColorPreset('Hefe', [contrastMatrix(0.1), saturationMatrix(0.15)]),
  ColorPreset('Helena', [overlayMatrix(208, 208, 86, 0.2), contrastMatrix(0.15)]),
  ColorPreset('Hudson', [rgbScaleMatrix(1, 1, 1.25), contrastMatrix(0.1), brightnessMatrix(0.15)]),
  ColorPreset('Inkwell', [grayscaleMatrix()]),
  ColorPreset('Invert', [invertMatrix()]),
  ColorPreset('Juno', [rgbScaleMatrix(1.01, 1.04, 1), saturationMatrix(0.3)]),
  ColorPreset('Kelvin', [overlayMatrix(255, 140, 0, 0.1), rgbScaleMatrix(1.15, 1.05, 1), saturationMatrix(0.35)]),
  ColorPreset('Lark', [brightnessMatrix(0.08), grayscaleMatrix(), contrastMatrix(-0.04)]),
  ColorPreset('Lo-Fi', [contrastMatrix(0.15), saturationMatrix(0.2)]),
  ColorPreset('Ludwig', [brightnessMatrix(0.05), saturationMatrix(-0.03)]),
  ColorPreset('Maven', [overlayMatrix(225, 240, 0, 0.1), saturationMatrix(0.25), contrastMatrix(0.05)]),
  ColorPreset('Mayfair', [overlayMatrix(230, 115, 108, 0.05), saturationMatrix(0.15)]),
  ColorPreset('Moon', [grayscaleMatrix(), contrastMatrix(-0.04), brightnessMatrix(0.1)]),
  ColorPreset('Nashville', [overlayMatrix(220, 115, 188, 0.12), contrastMatrix(-0.05)]),
  ColorPreset('Perpetua', [rgbScaleMatrix(1.05, 1.1, 1)]),
  ColorPreset('Reyes', [sepiaMatrix(0.4), brightnessMatrix(0.13), contrastMatrix(-0.05)]),
  ColorPreset('Rise', [overlayMatrix(255, 170, 0, 0.1), brightnessMatrix(0.09), saturationMatrix(0.1)]),
  ColorPreset('Sierra', [contrastMatrix(-0.15), saturationMatrix(0.1)]),
  ColorPreset('Skyline', [saturationMatrix(0.35), brightnessMatrix(0.1)]),
  ColorPreset('Slumber', [brightnessMatrix(0.1), saturationMatrix(-0.5)]),
  ColorPreset('Stinson', [brightnessMatrix(0.1), sepiaMatrix(0.3)]),
  ColorPreset('Sutro', [brightnessMatrix(-0.1), saturationMatrix(-0.1)]),
  ColorPreset('Toaster', [sepiaMatrix(0.1), overlayMatrix(255, 145, 0, 0.2)]),
  ColorPreset('Valencia', [overlayMatrix(255, 225, 80, 0.08), saturationMatrix(0.1), contrastMatrix(0.05)]),
  ColorPreset('Vesper', [overlayMatrix(255, 225, 0, 0.05), brightnessMatrix(0.06), contrastMatrix(0.06)]),
  ColorPreset('Walden', [brightnessMatrix(0.1), overlayMatrix(255, 255, 0, 0.2)]),
  ColorPreset('Willow', [grayscaleMatrix(), overlayMatrix(100, 28, 210, 0.03), brightnessMatrix(0.1)]),
  ColorPreset('X-Pro II', [overlayMatrix(255, 255, 0, 0.07), saturationMatrix(0.2), contrastMatrix(0.15)]),
];

const List<KernelEffect> kernelEffects = <KernelEffect>[
  KernelEffect('Sharpen', [-1, -1, -1, -1, 9, -1, -1, -1, -1]),
  KernelEffect('High Pass', [0, -0.25, 0, -0.25, 2, -0.25, 0, -0.25, 0]),
  KernelEffect('Edge', [-1, -1, -1, -1, 8, -1, -1, -1, -1]),
  KernelEffect('Emboss', [-1, -1, 0, -1, 0, 1, 0, 1, 1], bias: 128),
];

/// Slider values. Every field at 0 leaves the image unchanged.
class WallpaperAdjustments {
  const WallpaperAdjustments({this.blur = 0, this.hue = 0, this.saturation = 0, this.brightness = 0});

  /// 0..1 of the maximum blur.
  final double blur;

  /// -180..180 degrees.
  final double hue;

  /// -1 (grey) .. 1 (double colour).
  final double saturation;

  /// -1 (black) .. 1 (double light).
  final double brightness;

  static const WallpaperAdjustments none = WallpaperAdjustments();

  bool get isNone => blur == 0 && hue == 0 && saturation == 0 && brightness == 0;

  ColorMatrix get matrix => chainMatrices([
    if (hue != 0) hueMatrix(hue),
    if (saturation != 0) saturationMatrix(saturation),
    if (brightness != 0) exposureMatrix(1 + brightness),
  ]);

  WallpaperAdjustments copyWith({double? blur, double? hue, double? saturation, double? brightness}) =>
      WallpaperAdjustments(
        blur: blur ?? this.blur,
        hue: hue ?? this.hue,
        saturation: saturation ?? this.saturation,
        brightness: brightness ?? this.brightness,
      );
}
