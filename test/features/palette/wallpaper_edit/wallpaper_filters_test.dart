import 'package:Prism/features/palette/views/wallpaper_edit/color_matrix.dart';
import 'package:Prism/features/palette/views/wallpaper_edit/wallpaper_filters.dart';
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
      test('${preset.name} matches photofilters', () {
        final List<Step>? steps = photofiltersRecipes[preset.name];
        expect(steps, isNotNull);
        for (final Rgb input in const [
          [90.0, 120.0, 140.0],
          [60.0, 100.0, 30.0],
          [150.0, 110.0, 90.0],
        ]) {
          Rgb ref = input;
          bool clamped = false;
          for (final Step step in steps!) {
            final Rgb raw = step(ref);
            clamped = clamped || raw.any((v) => v < 0 || v > 255);
            ref = [for (final double v in raw) v.roundToDouble().clamp(0, 255).toDouble()];
          }
          if (clamped) continue;
          final Rgb got = [for (final double v in applyMatrix(preset.matrix, input)) v.clamp(0, 255).toDouble()];
          for (int i = 0; i < 3; i++) {
            expect(got[i], closeTo(ref[i], 1.5 * steps.length), reason: '${preset.name} $input channel $i');
          }
        }
      });
    }
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
