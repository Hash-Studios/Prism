import 'package:Prism/features/palette/views/wallpaper_edit/color_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reference_filters.dart';

void main() {
  const List<Rgb> colors = [
    [90, 120, 140],
    [60, 100, 30],
    [200, 80, 120],
  ];

  void expectClose(Rgb actual, Rgb expected, double tol) {
    for (int i = 0; i < 3; i++) {
      expect(actual[i], closeTo(expected[i], tol));
    }
  }

  group('ops match photofilters reference', () {
    final Map<String, (List<double>, Step)> ops = {
      'brightness': (brightnessMatrix(0.13), brightnessStep(0.13)),
      'contrast': (contrastMatrix(0.2), contrastStep(0.2)),
      'saturation': (saturationMatrix(0.35), saturationStep(0.35)),
      'grayscale': (grayscaleMatrix(), grayscaleStep()),
      'sepia': (sepiaMatrix(0.4), sepiaStep(0.4)),
      'rgbScale': (rgbScaleMatrix(1.05, 1.1, 0.9), rgbScaleStep(1.05, 1.1, 0.9)),
      'overlay': (overlayMatrix(228, 130, 225, 0.13), overlayStep(228, 130, 225, 0.13)),
      'additive': (additiveMatrix(10, 20, 30), additiveStep(10, 20, 30)),
      'invert': (invertMatrix(), invertStep()),
    };
    for (final MapEntry<String, (List<double>, Step)> op in ops.entries) {
      test(op.key, () {
        for (final Rgb c in colors) {
          expectClose(applyMatrix(op.value.$1, c), op.value.$2(c), 1e-6);
        }
      });
    }

    test('affine formulas remain correct at channel boundaries before clamping', () {
      const List<Rgb> boundaryColors = [
        [0, 0, 0],
        [255, 255, 255],
        [255, 0, 0],
        [0, 255, 255],
      ];
      for (final (List<double>, Step) op in ops.values) {
        for (final Rgb c in boundaryColors) {
          expectClose(applyMatrix(op.$1, c), op.$2(c), 1e-6);
        }
      }
    });
  });

  group('composeMatrices', () {
    final List<double> a = contrastMatrix(0.3);
    final List<double> b = additiveMatrix(40, 10, 60);

    test('applies first then second', () {
      final List<double> ab = composeMatrices(a, b);
      for (final Rgb c in colors) {
        expectClose(applyMatrix(ab, c), applyMatrix(b, applyMatrix(a, c)), 1e-6);
      }
    });

    test('is not commutative', () {
      final Rgb c = colors.first;
      final Rgb ab = applyMatrix(composeMatrices(a, b), c);
      final Rgb ba = applyMatrix(composeMatrices(b, a), c);
      expect((ab[0] - ba[0]).abs(), greaterThan(1));
    });
  });

  group('identity', () {
    test('chainMatrices of empty list is identity', () {
      expect(isIdentityMatrix(chainMatrices(const <List<double>>[])), isTrue);
    });
    test('identityMatrix is identity', () => expect(isIdentityMatrix(identityMatrix), isTrue));
    test('brightness 0.1 is not identity', () => expect(isIdentityMatrix(brightnessMatrix(0.1)), isFalse));
  });

  group('hueMatrix', () {
    test('0 degrees is identity', () {
      for (int i = 0; i < 20; i++) {
        expect(hueMatrix(0)[i], closeTo(identityMatrix[i], 1e-9));
      }
    });
    test('360 degrees is identity', () {
      for (int i = 0; i < 20; i++) {
        expect(hueMatrix(360)[i], closeTo(identityMatrix[i], 1e-9));
      }
    });
    test('grey stays grey at 90 degrees', () {
      final Rgb out = applyMatrix(hueMatrix(90), [128, 128, 128]);
      expectClose(out, [128, 128, 128], 1e-3);
    });
  });
}
