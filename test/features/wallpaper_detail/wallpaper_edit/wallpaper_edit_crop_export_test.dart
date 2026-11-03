import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Decoded = ({int width, int height, ByteData rgba});

const Color _red = Color(0xFFFF0000);
const Color _blue = Color(0xFF0000FF);

CropSpec spec(int w, int h) => CropSpec.initial(sourceWidth: w, sourceHeight: h, phoneAspect: 0.5);

Future<ui.Image> solidImage(int width, int height, Color color) =>
    paintRects(width, height, [(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), color)]);

Future<ui.Image> paintRects(int width, int height, List<(Rect, Color)> rects) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  for (final (Rect rect, Color color) in rects) {
    canvas.drawRect(rect, Paint()..color = color);
  }
  return rasterizePicture(recorder.endRecording(), width, height);
}

/// 40x20, red for x < 20 and blue for x >= 20.
Future<ui.Image> leftRedRightBlue() =>
    paintRects(40, 20, [(Rect.fromLTWH(0, 0, 20, 20), _red), (Rect.fromLTWH(20, 0, 20, 20), _blue)]);

/// 30x60, red for y < 30 and blue for y >= 30.
Future<ui.Image> topRedBottomBlue() =>
    paintRects(30, 60, [(Rect.fromLTWH(0, 0, 30, 30), _red), (Rect.fromLTWH(0, 30, 30, 30), _blue)]);

Future<_Decoded> decodePng(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  try {
    final ui.Image image = (await codec.getNextFrame()).image;
    try {
      final ByteData rgba = (await image.toByteData())!;
      return (width: image.width, height: image.height, rgba: rgba);
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

List<int> rgbaAt(_Decoded decoded, int x, int y) {
  final int offset = (y * decoded.width + x) * 4;
  return [for (int i = 0; i < 4; i++) decoded.rgba.getUint8(offset + i)];
}

void expectRed(List<int> px) {
  expect(px[0], greaterThan(245));
  expect(px[1], lessThan(10));
  expect(px[2], lessThan(10));
}

void expectBlue(List<int> px) {
  expect(px[0], lessThan(10));
  expect(px[1], lessThan(10));
  expect(px[2], greaterThan(245));
}

Future<_Decoded> renderAndDecode(
  ui.Image source, {
  CropSpec? crop,
  List<WallpaperFilter> stack = const <WallpaperFilter>[],
  double deviceLongSidePx = 0,
}) async {
  final Uint8List png = await renderEditedPng(
    source,
    stack,
    WallpaperAdjustments.none,
    crop: crop,
    deviceLongSidePx: deviceLongSidePx,
  );
  return decodePng(png);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ColorPreset invert = colorPresets.firstWhere((p) => p.name == 'Invert');

  testWidgets('square crop of a portrait source exports a square', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await solidImage(1001, 1999, _red);
      try {
        final _Decoded out = await renderAndDecode(source, crop: spec(1001, 1999).withPreset(CropPreset.square));
        expect((out.width, out.height), (1001, 1001));
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('landscape crop of a portrait source exports 16:9', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await solidImage(1001, 1999, _red);
      try {
        final _Decoded out = await renderAndDecode(source, crop: spec(1001, 1999).withPreset(CropPreset.landscape));
        expect((out.width, out.height), (1001, 563));
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('no crop keeps the source size', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await solidImage(1001, 1999, _red);
      try {
        final _Decoded none = await renderAndDecode(source);
        expect((none.width, none.height), (1001, 1999));
        final _Decoded identity = await renderAndDecode(source, crop: spec(1001, 1999));
        expect((identity.width, identity.height), (1001, 1999));
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('no crop is capped at 4096 on the long side', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await solidImage(5000, 3000, _red);
      try {
        final _Decoded capped = await renderAndDecode(source);
        expect((capped.width, capped.height), (4096, 2458));
        final _Decoded cropped = await renderAndDecode(source, crop: spec(5000, 3000).withPreset(CropPreset.square));
        expect((cropped.width, cropped.height), (3000, 3000));
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('crop exports the kept region in view orientation', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await leftRedRightBlue();
      try {
        final CropSpec crop = spec(40, 20).withPreset(CropPreset.free).resized(CropCorner.topLeft, 20, 0);
        final _Decoded out = await renderAndDecode(source, crop: crop);
        expect((out.width, out.height), (20, 20));
        expectBlue(rgbaAt(out, 10, 10));
        expectBlue(rgbaAt(out, 1, 1));
        expectBlue(rgbaAt(out, 18, 18));
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('one quarter turn exports a 20x40 image with the source turned clockwise', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await leftRedRightBlue();
      try {
        final CropSpec crop = spec(40, 20).withPreset(CropPreset.free).rotated();
        final _Decoded out = await renderAndDecode(source, crop: crop);
        expect((out.width, out.height), (20, 40));
        expectRed(rgbaAt(out, 10, 5));
        expectBlue(rgbaAt(out, 10, 35));
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('two quarter turns exports a 40x20 image upside down', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await leftRedRightBlue();
      try {
        final CropSpec crop = spec(40, 20).withPreset(CropPreset.free).rotated().rotated();
        final _Decoded out = await renderAndDecode(source, crop: crop);
        expect((out.width, out.height), (40, 20));
        expectBlue(rgbaAt(out, 5, 10));
        expectRed(rgbaAt(out, 35, 10));
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('three quarter turns exports a 20x40 image turned counter-clockwise', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await leftRedRightBlue();
      try {
        final CropSpec crop = spec(40, 20).withPreset(CropPreset.free).rotated().rotated().rotated();
        final _Decoded out = await renderAndDecode(source, crop: crop);
        expect((out.width, out.height), (20, 40));
        expectBlue(rgbaAt(out, 10, 5));
        expectRed(rgbaAt(out, 10, 35));
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('filters run on the cropped area', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await leftRedRightBlue();
      try {
        final CropSpec crop = spec(40, 20).withPreset(CropPreset.free).resized(CropCorner.topLeft, 20, 0);
        final _Decoded out = await renderAndDecode(source, crop: crop, stack: <WallpaperFilter>[invert]);
        expect((out.width, out.height), (20, 20));
        final List<int> px = rgbaAt(out, 10, 10);
        expect(px[0], greaterThan(245));
        expect(px[1], greaterThan(245));
        expect(px[2], lessThan(10));
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('a crop for another source size throws', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await leftRedRightBlue();
      try {
        await expectLater(
          renderEditedPng(
            source,
            const <WallpaperFilter>[],
            WallpaperAdjustments.none,
            crop: spec(41, 20).withPreset(CropPreset.square),
          ),
          throwsStateError,
        );
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('renderEditedFile decodes the file and exports the cropped region', (tester) async {
    await tester.runAsync(() async {
      final Directory dir = await Directory.systemTemp.createTemp('crop_export_test_');
      addTearDown(() => dir.delete(recursive: true));
      final ui.Image source = await topRedBottomBlue();
      final ByteData pngBytes;
      try {
        pngBytes = (await source.toByteData(format: ui.ImageByteFormat.png))!;
      } finally {
        source.dispose();
      }
      final File file = File('${dir.path}/source.png');
      await file.writeAsBytes(pngBytes.buffer.asUint8List());

      final Uint8List png = await renderEditedFile(
        file.path,
        stack: const <WallpaperFilter>[],
        adjustments: WallpaperAdjustments.none,
        crop: spec(30, 60).withPreset(CropPreset.free).resized(CropCorner.bottomRight, 0, -30),
      );
      final _Decoded out = await decodePng(png);
      expect((out.width, out.height), (30, 30));
      expectRed(rgbaAt(out, 15, 15));
    });
  });

  test('withExportTimeLimit throws EditExportTimedOut when the export never finishes', () async {
    final Completer<int> never = Completer<int>();
    await expectLater(
      withExportTimeLimit(never.future, limit: const Duration(milliseconds: 20)),
      throwsA(isA<EditExportTimedOut>()),
    );
  });

  test('withExportTimeLimit returns the result of a finished export', () async {
    expect(await withExportTimeLimit(Future.value(7)), 7);
  });
}
