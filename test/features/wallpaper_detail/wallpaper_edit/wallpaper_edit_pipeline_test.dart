import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingPicture implements ui.Picture {
  bool disposed = false;

  @override
  Future<ui.Image> toImage(int width, int height) async => throw StateError('rasterization failed');

  @override
  void dispose() => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ui.Image> solidImage(int width, int height, Color color) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
  final ui.Picture picture = recorder.endRecording();
  return rasterizePicture(picture, width, height);
}

Future<ui.Image> gradientImage({required int width, required int height, int alpha = 255}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
        Paint()..color = Color.fromARGB(alpha, x * 4, y * 2, 32),
      );
    }
  }
  return rasterizePicture(recorder.endRecording(), width, height);
}

Future<List<int>> renderKernelPixel(
  ui.Image source,
  KernelEffect effect, {
  required double scale,
  double lightness = 0,
}) async {
  final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset('shaders/convolve3x3.frag');
  final ui.FragmentShader shader = program.fragmentShader();
  shader.setFloat(0, source.width.toDouble());
  shader.setFloat(1, source.height.toDouble());
  for (int i = 0; i < effect.kernel.length; i++) {
    shader.setFloat(2 + i, effect.kernel[i]);
  }
  shader.setFloat(11, effect.bias / 255);
  shader.setFloat(12, scale);
  shader.setFloat(13, lightness);
  shader.setImageSampler(0, source);

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()), Paint()..shader = shader);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image rendered = await rasterizePicture(picture, source.width, source.height);
  try {
    final ByteData bytes = (await rendered.toByteData())!;
    final int offset = (16 * source.width + 16) * 4;
    return [bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2), bytes.getUint8(offset + 3)];
  } finally {
    rendered.dispose();
    shader.dispose();
  }
}

Future<List<int>> centrePixel(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  try {
    final ui.Image image = (await codec.getNextFrame()).image;
    try {
      final ByteData data = (await image.toByteData())!;
      final int o = (2 * image.width + 2) * 4;
      return [data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2)];
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ColorPreset invert = colorPresets.firstWhere((p) => p.name == 'Invert');

  test('buildEditFilter returns null for an empty edit', () {
    expect(buildEditFilter(const [], WallpaperAdjustments.none, 100), isNull);
  });

  test('buildEditFilter returns a filter for a preset', () {
    expect(buildEditFilter([invert], WallpaperAdjustments.none, 100), isNotNull);
  });

  test('buildEditFilter returns a filter for blur', () {
    expect(
      buildEditFilter(const [], const WallpaperAdjustments(blur: 0.5), 400),
      ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8, tileMode: TileMode.mirror),
    );
  });

  test('export scales 3x3 taps to the preview pixel size', () {
    expect(kernelScaleForExport(4000, 1000), 4);
    expect(kernelScaleForExport(4000, 4000), 1);
  });

  testWidgets('lightness preserves HSL hue and saturation, including transparent pixels', (tester) async {
    await tester.runAsync(() async {
      const identity = KernelEffect('Lightness', [0, 0, 0, 0, 1, 0, 0, 0, 0]);
      const colors = [
        Color(0xFFFF0000),
        Color(0xFF26A853),
        Color(0xFFCC99BB),
        Color(0xFF808080),
        Color(0xFF000000),
        Color(0xFFFFFFFF),
        Color(0x80FF0000),
        Color(0x00FF0000),
      ];
      for (final color in colors) {
        final source = await solidImage(33, 33, color);
        try {
          for (final adjustment in [-1.0, -0.25, 0.25, 1.0]) {
            final pixel = await renderKernelPixel(source, identity, scale: 1, lightness: adjustment);
            final hsl = HSLColor.fromColor(color);
            final expected = hsl.withLightness((hsl.lightness + adjustment).clamp(0, 1)).toColor();
            final channels = [expected.r, expected.g, expected.b];
            for (var channel = 0; channel < 3; channel++) {
              expect(
                pixel[channel],
                closeTo(channels[channel] * expected.a * 255, 1.5),
                reason: '$color, lightness $adjustment, channel $channel',
              );
            }
            expect(pixel[3], (color.a * 255).round());
          }
        } finally {
          source.dispose();
        }
      }
    });
  });

  testWidgets('Emboss kernel scale changes directional RGB while preserving alpha', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await gradientImage(width: 33, height: 33, alpha: 128);
      try {
        final KernelEffect emboss = kernelEffects.last;
        final List<int> scaleOne = await renderKernelPixel(source, emboss, scale: 1);
        final List<int> scaleFour = await renderKernelPixel(source, emboss, scale: 4);
        expect(scaleOne, [72, 68, 64, 128]);
        expect(scaleFour, [96, 80, 64, 128]);
      } finally {
        source.dispose();
      }
    });
  });

  test('rasterizePicture disposes its picture when rasterization fails', () async {
    final _ThrowingPicture picture = _ThrowingPicture();
    await expectLater(rasterizePicture(picture, 1, 1), throwsStateError);
    expect(picture.disposed, isTrue);
  });

  testWidgets('renderEditedPng inverts red to cyan', (tester) async {
    await tester.runAsync(() async {
      final ui.Image image = await solidImage(4, 4, const Color(0xFFFF0000));
      try {
        final List<int> px = await centrePixel(await renderEditedPng(image, [invert], WallpaperAdjustments.none));
        expect(px[0], inInclusiveRange(0, 2));
        expect(px[1], inInclusiveRange(253, 255));
        expect(px[2], inInclusiveRange(253, 255));
      } finally {
        image.dispose();
      }
    });
  });

  testWidgets('renderEditedPng applies HSL lightness through the production pipeline', (tester) async {
    await tester.runAsync(() async {
      expect(await loadKernelEffects(), isTrue);
      final ui.Image image = await solidImage(5, 5, const Color(0xFFFF0000));
      try {
        final List<int> lighter = await centrePixel(
          await renderEditedPng(image, const [], const WallpaperAdjustments(lightness: 0.25)),
        );
        final List<int> darker = await centrePixel(
          await renderEditedPng(image, const [], const WallpaperAdjustments(lightness: -0.25)),
        );
        for (int channel = 0; channel < 3; channel++) {
          expect(lighter[channel], closeTo([255, 128, 128][channel], 1));
          expect(darker[channel], closeTo([128, 0, 0][channel], 1));
        }
      } finally {
        image.dispose();
      }
    });
  }, skip: !ui.ImageFilter.isShaderFilterSupported);

  testWidgets('renderEditedPng with no edit keeps red', (tester) async {
    await tester.runAsync(() async {
      final ui.Image image = await solidImage(4, 4, const Color(0xFFFF0000));
      try {
        final List<int> px = await centrePixel(await renderEditedPng(image, const [], WallpaperAdjustments.none));
        expect(px[0], inInclusiveRange(253, 255));
        expect(px[1], inInclusiveRange(0, 2));
        expect(px[2], inInclusiveRange(0, 2));
      } finally {
        image.dispose();
      }
    });
  });

  testWidgets('outputSize scales the kept source region through every quarter turn', (tester) async {
    await tester.runAsync(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..drawRect(const Rect.fromLTWH(0, 0, 20, 10), Paint()..color = const Color(0xFFFF0000))
        ..drawRect(const Rect.fromLTWH(20, 0, 20, 10), Paint()..color = const Color(0xFF0000FF))
        ..drawRect(const Rect.fromLTWH(0, 10, 20, 10), Paint()..color = const Color(0xFF00FF00))
        ..drawRect(const Rect.fromLTWH(20, 10, 20, 10), Paint()..color = const Color(0xFFFFFF00));
      final ui.Image source = await rasterizePicture(recorder.endRecording(), 40, 20);
      try {
        for (int turns = 0; turns < 4; turns++) {
          CropSpec crop = CropSpec.initial(
            sourceWidth: 40,
            sourceHeight: 20,
            phoneAspect: 0.5,
          ).withPreset(CropPreset.free).resized(CropCorner.topLeft, 10, 4).resized(CropCorner.bottomRight, -5, -3);
          for (int i = 0; i < turns; i++) {
            crop = crop.rotated();
          }
          final size = turns.isOdd ? (width: 78, height: 150) : (width: 150, height: 78);
          final Uint8List png = await renderEditedPng(
            source,
            const [],
            WallpaperAdjustments.none,
            crop: crop,
            outputSize: size,
          );
          final ui.Codec codec = await ui.instantiateImageCodec(png);
          final ui.Image output = (await codec.getNextFrame()).image;
          try {
            expect((output.width, output.height), (size.width, size.height));
            final ByteData rgba = (await output.toByteData())!;
            final List<(double, double, List<int>)> regions = switch (turns) {
              0 => [
                (0.2, 0.2, [255, 0, 0, 255]),
                (0.8, 0.2, [0, 0, 255, 255]),
                (0.2, 0.8, [0, 255, 0, 255]),
                (0.8, 0.8, [255, 255, 0, 255]),
                (0.49, 0.2, [0, 0, 255, 255]),
              ],
              1 => [
                (0.8, 0.2, [255, 0, 0, 255]),
                (0.8, 0.8, [0, 0, 255, 255]),
                (0.2, 0.2, [0, 255, 0, 255]),
                (0.2, 0.8, [255, 255, 0, 255]),
                (0.8, 0.49, [0, 0, 255, 255]),
              ],
              2 => [
                (0.8, 0.8, [255, 0, 0, 255]),
                (0.2, 0.8, [0, 0, 255, 255]),
                (0.8, 0.2, [0, 255, 0, 255]),
                (0.2, 0.2, [255, 255, 0, 255]),
                (0.51, 0.8, [0, 0, 255, 255]),
              ],
              _ => [
                (0.2, 0.8, [255, 0, 0, 255]),
                (0.2, 0.2, [0, 0, 255, 255]),
                (0.8, 0.8, [0, 255, 0, 255]),
                (0.8, 0.2, [255, 255, 0, 255]),
                (0.2, 0.51, [0, 0, 255, 255]),
              ],
            };
            for (final (double x, double y, List<int> color) in regions) {
              final int pixel = ((output.height * y).floor() * output.width + (output.width * x).floor()) * 4;
              expect([for (int i = 0; i < 4; i++) rgba.getUint8(pixel + i)], color, reason: 'turns=$turns at ($x, $y)');
            }
          } finally {
            output.dispose();
            codec.dispose();
          }
        }
      } finally {
        source.dispose();
      }
    });
  });

  group('exportSize', () {
    test('leaves images within the cap alone', () {
      expect(exportSize(1080, 2400), (width: 1080, height: 2400));
      expect(exportSize(4096, 3000), (width: 4096, height: 3000));
    });

    test('caps the long side at 4096 and keeps the ratio', () {
      expect(exportSize(6000, 3000), (width: 4096, height: 2048));
      expect(exportSize(3000, 8192), (width: 1500, height: 4096));
    });

    test('lets a larger device screen raise the cap', () {
      expect(exportSize(6000, 3000, deviceLongSidePx: 5000), (width: 5000, height: 2500));
      expect(exportSize(6000, 3000, deviceLongSidePx: 1000), (width: 4096, height: 2048));
    });
  });

  testWidgets('renderEditedPng scales an oversize image down to the cap', (tester) async {
    await tester.runAsync(() async {
      final ui.Image image = await solidImage(4200, 4, const Color(0xFFFF0000));
      try {
        final Uint8List png = await renderEditedPng(image, const [], WallpaperAdjustments.none);
        final ui.Codec codec = await ui.instantiateImageCodec(png);
        final ui.Image out = (await codec.getNextFrame()).image;
        expect((out.width, out.height), (4096, 4));
        out.dispose();
        codec.dispose();
      } finally {
        image.dispose();
      }
    });
  });
}
