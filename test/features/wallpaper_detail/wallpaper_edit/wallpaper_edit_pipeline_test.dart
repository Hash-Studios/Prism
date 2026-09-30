import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

Future<List<int>> renderKernelPixel(ui.Image source, KernelEffect effect, {required double scale}) async {
  final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset('shaders/convolve3x3.frag');
  final ui.FragmentShader shader = program.fragmentShader();
  shader.setFloat(0, source.width.toDouble());
  shader.setFloat(1, source.height.toDouble());
  for (int i = 0; i < effect.kernel.length; i++) {
    shader.setFloat(2 + i, effect.kernel[i]);
  }
  shader.setFloat(11, effect.bias / 255);
  shader.setFloat(12, scale);
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

  test('GLES compile contract reverses only tap direction after UV flip', () {
    final String shader = File('shaders/convolve3x3.frag').readAsStringSync();
    expect(shader, contains('#ifdef IMPELLER_TARGET_OPENGLES\n  dy = -dy;\n#endif'));
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

  testWidgets('loadKernelEffects completes', (tester) async {
    await tester.runAsync(() async {
      await expectLater(loadKernelEffects(), completion(isA<bool>()));
    });
  });
}
