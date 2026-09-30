import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/color_matrix.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reference_filters.dart';

void main() {
  group('colorPresets', () {
    test('names are unique', () {
      final List<String> names = colorPresets.map((p) => p.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('cover exactly the photofilters recipes', () {
      expect(colorPresets.map((p) => p.name).toSet(), photofiltersRecipes.keys.toSet());
    });

    for (final ColorPreset preset in colorPresets) {
      test('${preset.name} matches the affine photofilters recipe', () {
        final List<Step>? steps = photofiltersRecipes[preset.name];
        expect(steps, isNotNull);
        for (final Rgb input in const [
          [0.0, 0.0, 0.0],
          [255.0, 255.0, 255.0],
          [255.0, 0.0, 0.0],
          [0.0, 255.0, 0.0],
          [0.0, 0.0, 255.0],
          [90.0, 120.0, 140.0],
          [60.0, 100.0, 30.0],
          [150.0, 110.0, 90.0],
        ]) {
          Rgb ref = input;
          for (final Step step in steps!) {
            ref = step(ref);
          }
          final Rgb got = applyMatrix(preset.matrix, input);
          for (int i = 0; i < 3; i++) {
            expect(got[i], closeTo(ref[i], 1e-6), reason: '${preset.name} $input channel $i');
          }
        }
      });
    }

    test('Amaro composes affine steps and clamps only after the combined matrix', () {
      const Rgb input = [255, 0, 0];
      final List<double> matrixOutput = applyMatrix(
        colorPresets.singleWhere((preset) => preset.name == 'Amaro').matrix,
        input,
      );
      Rgb photofiltersOutput = input;
      for (final Step step in photofiltersRecipes['Amaro']!) {
        photofiltersOutput = [
          for (final double channel in step(photofiltersOutput)) channel.roundToDouble().clamp(0, 255).toDouble(),
        ];
      }

      // One 4x5 matrix cannot retain photofilters' intermediate per-step clamps.
      expect(photofiltersOutput, [255, 38, 38]);
      expect(matrixOutput[0].clamp(0, 255), 255);
      expect(matrixOutput[1], closeTo(15.13415, 1e-5));
      expect(matrixOutput[2], closeTo(15.13415, 1e-5));
    });
  });

  test('kernelEffects', () {
    expect(kernelEffects.map((k) => k.name).toList(), ['Sharpen', 'High Pass', 'Edge', 'Emboss']);
    for (final KernelEffect k in kernelEffects) {
      expect(k.kernel.length, 9);
    }
  });

  group('WallpaperAdjustments', () {
    test('none is none with identity matrix', () {
      expect(WallpaperAdjustments.none.isNone, isTrue);
      expect(isIdentityMatrix(WallpaperAdjustments.none.matrix), isTrue);
    });

    test('brightness 0.5 maps 100 to 150', () {
      final Rgb out = applyMatrix(const WallpaperAdjustments(brightness: 0.5).matrix, [100, 100, 100]);
      for (final double v in out) {
        expect(v, closeTo(150, 1e-6));
      }
    });

    test('copyWith keeps untouched fields', () {
      const WallpaperAdjustments a = WallpaperAdjustments(blur: 0.1, hue: 20, saturation: 0.3, brightness: 0.4);
      final WallpaperAdjustments b = a.copyWith(hue: 50);
      expect((b.blur, b.hue, b.saturation, b.brightness), (0.1, 50.0, 0.3, 0.4));
    });
  });
}
