import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:flutter_test/flutter_test.dart';

CropSpec spec(int w, int h, {double phone = 0.5}) =>
    CropSpec.initial(sourceWidth: w, sourceHeight: h, phoneAspect: phone);

void main() {
  test('scaledTo keeps a rounded preview of an original crop whole through every turn', () {
    for (int turns = 0; turns < 4; turns++) {
      CropSpec preview = spec(1201, 1600);
      for (int i = 0; i < turns; i++) {
        preview = preview.rotated();
      }
      final CropSpec full = preview.scaledTo(sourceWidth: 3001, sourceHeight: 4000);
      expect(full.sourceRect, const PixelRect(0, 0, 3001, 4000), reason: 'turns=$turns');
      expect(full.rect, turns.isOdd ? const PixelRect(0, 0, 4000, 3001) : const PixelRect(0, 0, 3001, 4000));
    }
  });

  group('presets on a portrait source', () {
    test('initial frame is the whole image with original preset', () {
      final CropSpec s = spec(1080, 1920);
      expect(s.rect, const PixelRect(0, 0, 1080, 1920));
      expect(s.preset, CropPreset.original);
      expect(s.isIdentity, isTrue);
      expect(s.adjusted, isFalse);
      expect(s.outputWidth, 1080);
      expect(s.outputHeight, 1920);
    });

    test('square preset centres a 1:1 frame', () {
      final CropSpec s = spec(1080, 1920).withPreset(CropPreset.square);
      expect(s.rect, const PixelRect(0, 420, 1080, 1080));
      expect(s.isIdentity, isFalse);
      expect(s.adjusted, isFalse);
    });

    test('portrait preset keeps the whole 9:16 image', () {
      final CropSpec s = spec(1080, 1920).withPreset(CropPreset.portrait);
      expect(s.rect, const PixelRect(0, 0, 1080, 1920));
      expect(s.isIdentity, isTrue);
    });

    test('landscape preset centres a 16:9 frame', () {
      final CropSpec s = spec(1080, 1920).withPreset(CropPreset.landscape);
      expect(s.rect, const PixelRect(0, 656, 1080, 608));
    });

    test('phone preset uses the phone aspect', () {
      final CropSpec s = spec(1080, 1920).withPreset(CropPreset.phone);
      expect(s.rect, const PixelRect(60, 0, 960, 1920));
    });

    test('free preset keeps the current rect', () {
      final CropSpec s = spec(1080, 1920).withPreset(CropPreset.free);
      expect(s.rect, const PixelRect(0, 0, 1080, 1920));
      expect(s.preset, CropPreset.free);
    });
  });

  group('presets on a landscape source', () {
    test('square preset centres a 1:1 frame', () {
      final CropSpec s = spec(1920, 1080).withPreset(CropPreset.square);
      expect(s.rect, const PixelRect(420, 0, 1080, 1080));
    });

    test('portrait preset centres a 9:16 frame', () {
      final CropSpec s = spec(1920, 1080).withPreset(CropPreset.portrait);
      expect(s.rect, const PixelRect(656, 0, 608, 1080));
    });

    test('landscape preset keeps the whole image', () {
      final CropSpec s = spec(1920, 1080).withPreset(CropPreset.landscape);
      expect(s.rect, const PixelRect(0, 0, 1920, 1080));
      expect(s.isIdentity, isTrue);
    });

    test('original preset keeps the whole image', () {
      final CropSpec s = spec(1920, 1080).withPreset(CropPreset.original);
      expect(s.rect, const PixelRect(0, 0, 1920, 1080));
    });
  });

  group('phone aspect', () {
    test('a phone aspect above one is inverted to portrait', () {
      final CropSpec s = CropSpec.initial(sourceWidth: 1000, sourceHeight: 1000, phoneAspect: 2);
      expect(s.phoneAspect, 0.5);
    });

    test('a zero phone aspect falls back to 9/16', () {
      final CropSpec s = CropSpec.initial(sourceWidth: 1000, sourceHeight: 1000, phoneAspect: 0);
      expect(s.phoneAspect, closeTo(0.5625, 1e-9));
    });

    test('an empty source throws an ArgumentError', () {
      expect(() => CropSpec.initial(sourceWidth: 0, sourceHeight: 1000, phoneAspect: 0.5), throwsArgumentError);
    });
  });

  group('clamping', () {
    final CropSpec start = spec(1080, 1920).withPreset(CropPreset.square);

    test('a move far past the top left corner stops at the image edge', () {
      final CropSpec s = start.moved(5000, -5000);
      expect(s.rect, const PixelRect(0, 0, 1080, 1080));
      expect(s.adjusted, isTrue);
    });

    test('a move down stops at the bottom edge', () {
      expect(start.moved(0, 5000).rect, const PixelRect(0, 840, 1080, 1080));
    });

    test('a fractional move rounds to whole pixels', () {
      expect(start.moved(0, 10.4).rect, const PixelRect(0, 430, 1080, 1080));
    });

    test('resizing past the minimum side stops at minSide', () {
      expect(
        spec(1080, 1920).withPreset(CropPreset.free).resized(CropCorner.bottomRight, -2000, -3000).rect,
        const PixelRect(0, 0, 108, 108),
      );
    });

    test('minSide is a tenth of the short side', () {
      expect(spec(1080, 1920).minSide, 108);
    });

    test('resizing the top left corner moves the left and top edges', () {
      expect(
        spec(1080, 1920).withPreset(CropPreset.free).resized(CropCorner.topLeft, 50, 100).rect,
        const PixelRect(50, 100, 1030, 1820),
      );
    });

    test('resizing the top left corner past the image edge fills the image', () {
      expect(spec(1080, 1920).resized(CropCorner.topLeft, -500, -500).rect, const PixelRect(0, 0, 1080, 1920));
    });

    test('resizing a corner keeps the preset aspect', () {
      expect(start.resized(CropCorner.bottomRight, -540, 0).rect, const PixelRect(0, 420, 810, 810));
    });

    test('scaling by 0.5 halves the frame about its centre', () {
      expect(start.scaled(0.5).rect, const PixelRect(270, 690, 540, 540));
    });

    test('scaling past the image fills the image on the preset aspect', () {
      expect(start.scaled(10).rect, const PixelRect(0, 420, 1080, 1080));
    });

    test('scaling far below the minimum stops at minSide', () {
      expect(start.scaled(0.0001).rect, const PixelRect(486, 906, 108, 108));
    });

    test('every preset and corner stays inside the image at a minimum size', () {
      for (final CropPreset p in CropPreset.values) {
        for (final CropCorner corner in CropCorner.values) {
          final CropSpec s = spec(1001, 1999).withPreset(p).resized(corner, 3000, -3000).moved(-9999, 9999);
          final PixelRect r = s.rect;
          expect(r.left, greaterThanOrEqualTo(0), reason: '$p $corner');
          expect(r.top, greaterThanOrEqualTo(0), reason: '$p $corner');
          expect(r.right, lessThanOrEqualTo(s.viewWidth), reason: '$p $corner');
          expect(r.bottom, lessThanOrEqualTo(s.viewHeight), reason: '$p $corner');
          expect(r.width, greaterThanOrEqualTo(1), reason: '$p $corner');
          expect(r.height, greaterThanOrEqualTo(1), reason: '$p $corner');
        }
      }
    });

    test('minimum side holds through all turns and extreme gestures on normal and tiny images', () {
      for (final (int width, int height) in [(1001, 1999), (3, 7), (1, 1)]) {
        for (final CropPreset preset in CropPreset.values) {
          for (int turns = 0; turns < 4; turns++) {
            for (final CropCorner corner in CropCorner.values) {
              CropSpec s = spec(width, height).withPreset(preset);
              for (int i = 0; i < turns; i++) {
                s = s.rotated();
              }
              s = s.resized(corner, -corner.sx * 10000, -corner.sy * 10000).moved(10000, -10000);
              expect(s.rect.width, greaterThanOrEqualTo(s.minSide), reason: '$width x $height $preset $turns $corner');
              expect(s.rect.height, greaterThanOrEqualTo(s.minSide), reason: '$width x $height $preset $turns $corner');
            }
          }
        }
      }
    });
  });

  group('rotate', () {
    test('a single turn swaps the view and keeps the whole image', () {
      final CropSpec s = spec(1000, 600).rotated();
      expect(s.quarterTurns, 1);
      expect(s.viewWidth, 600);
      expect(s.viewHeight, 1000);
      expect(s.rect, const PixelRect(0, 0, 600, 1000));
      expect(s.sourceRect, const PixelRect(0, 0, 1000, 600));
      expect(s.isIdentity, isFalse);
      expect(s.outputWidth, 600);
      expect(s.outputHeight, 1000);
    });

    test('a turn moves the square frame with the image', () {
      final CropSpec square = spec(1000, 600).withPreset(CropPreset.square);
      expect(square.rect, const PixelRect(200, 0, 600, 600));

      final CropSpec turned = square.rotated();
      expect(turned.rect, const PixelRect(0, 200, 600, 600));
      expect(turned.sourceRect, const PixelRect(200, 0, 600, 600));
    });

    test('four turns return to the start orientation and frame', () {
      final CropSpec square = spec(1000, 600).withPreset(CropPreset.square);
      final CropSpec back = square.rotated().rotated().rotated().rotated();
      expect(back.quarterTurns, 0);
      expect(back.rect, const PixelRect(200, 0, 600, 600));
    });

    test('a turn refits a portrait frame to its aspect', () {
      final CropSpec portrait = spec(1000, 600).withPreset(CropPreset.portrait);
      expect(portrait.rect, const PixelRect(331, 0, 338, 600));

      final CropSpec turned = portrait.rotated();
      expect(turned.rect, const PixelRect(19, 0, 563, 1000));
      expect(turned.preset, CropPreset.portrait);
    });

    test('two turns flip the image upside down and keep its size', () {
      final CropSpec s = spec(1000, 600).rotated().rotated();
      expect(s.quarterTurns, 2);
      expect(s.rect, const PixelRect(0, 0, 1000, 600));
      expect(s.sourceRect, const PixelRect(0, 0, 1000, 600));
    });

    test('source rect maps a resize at zero turns back to the source', () {
      final CropSpec s = spec(1000, 600).withPreset(CropPreset.free).resized(CropCorner.bottomRight, -400, -100);
      expect(s.quarterTurns, 0);
      expect(s.rect, const PixelRect(0, 0, 600, 500));
      expect(s.sourceRect, const PixelRect(0, 0, 600, 500));
    });

    test('source rect maps a resize after three turns back to the source', () {
      final CropSpec turned = spec(1000, 600).withPreset(CropPreset.free).rotated().rotated().rotated();
      final CropSpec s = turned.resized(CropCorner.bottomRight, -100, -400);
      expect(s.rect, const PixelRect(0, 0, 500, 600));
      expect(s.sourceRect, const PixelRect(400, 0, 600, 500));
    });
  });

  group('odd sizes', () {
    test('square preset on 1001x1999 centres an odd-sized frame', () {
      final CropSpec s = spec(1001, 1999).withPreset(CropPreset.square);
      expect(s.rect, const PixelRect(0, 499, 1001, 1001));
      expect(s.sourceRect, const PixelRect(0, 499, 1001, 1001));
      expect(s.outputWidth, 1001);
      expect(s.outputHeight, 1001);
    });

    test('landscape preset on 1001x1999 centres a 16:9 frame', () {
      expect(spec(1001, 1999).withPreset(CropPreset.landscape).rect, const PixelRect(0, 718, 1001, 563));
    });

    test('portrait preset on 1001x1999 centres a 9:16 frame', () {
      expect(spec(1001, 1999).withPreset(CropPreset.portrait).rect, const PixelRect(0, 110, 1001, 1780));
    });
  });

  group('reset and flags', () {
    test('reset returns the spec to its initial state', () {
      final CropSpec s = spec(1080, 1920).withPreset(CropPreset.square).moved(0, 1).rotated().reset();
      expect(s, spec(1080, 1920));
    });

    test('moving the frame marks it adjusted', () {
      expect(spec(1080, 1920).withPreset(CropPreset.square).moved(0, 1).adjusted, isTrue);
    });

    test('choosing a preset clears the adjusted flag', () {
      final CropSpec s = spec(1080, 1920).moved(0, 1).withPreset(CropPreset.free);
      expect(s.adjusted, isFalse);
    });

    test('scaling marks the frame adjusted', () {
      expect(spec(1080, 1920).withPreset(CropPreset.square).scaled(0.5).adjusted, isTrue);
    });

    test('resizing marks the frame adjusted', () {
      expect(spec(1080, 1920).resized(CropCorner.topLeft, 50, 100).adjusted, isTrue);
    });
  });
}
