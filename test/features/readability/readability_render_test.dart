import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/readability/data/readability_render.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/readability/views/readability_views.dart';
import 'package:Prism/features/wallpaper_position/data/placement_renderer.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);
const Color _white = Color(0xFFFFFFFF);

const ReadabilityFix _clockDim = ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.dim);
const ReadabilityFix _iconsDim = ReadabilityFix(ReadabilityZone.icons, ReadabilityFixKind.dim);
const ReadabilityFix _clockBlur = ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.blur);
const ReadabilityFix _iconsBlur = ReadabilityFix(ReadabilityZone.icons, ReadabilityFixKind.blur);

Future<ui.Image> _solid(int width, int height, Color color) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Offset.zero & Size(width.toDouble(), height.toDouble()), Paint()..color = color);
  return recorder.endRecording().toImage(width, height);
}

/// Left half blue, right half red.
Future<ui.Image> _twoHalves(int width, int height) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width / 2, height.toDouble()), Paint()..color = const Color(0xFF0000FF));
  canvas.drawRect(Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()), Paint()..color = const Color(0xFFFF0000));
  return recorder.endRecording().toImage(width, height);
}

class _Decoded {
  _Decoded(this.image, this.data);

  final ui.Image image;
  final ByteData data;

  (int, int, int) pixel(int x, int y) {
    final int offset = (y * image.width + x) * 4;
    return (data.getUint8(offset), data.getUint8(offset + 1), data.getUint8(offset + 2));
  }
}

Future<_Decoded> _decode(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  return _Decoded(image, (await image.toByteData())!);
}

/// Renders [source] through [renderReadabilityFrame] and reads the pixels back.
Future<_Decoded> _frame(
  ui.Image source, {
  required int width,
  required int height,
  ui.Color? tint,
  List<ReadabilityFix> fixes = const <ReadabilityFix>[],
}) async {
  final ui.Image image = await renderReadabilityFrame(
    source,
    width: width,
    height: height,
    platform: TargetPlatform.android,
    tint: tint,
    fixes: fixes,
  );
  return _Decoded(image, (await image.toByteData())!);
}

void main() {
  testWidgets('changing the source disposes the old fixed preview before decoding the replacement', (tester) async {
    final (Uint8List, Uint8List)? pngs = await tester.runAsync(() async {
      final ui.Image firstSource = await _solid(40, 80, _white);
      final ui.Image secondSource = await _solid(40, 80, _red);
      final Uint8List firstBytes = (await firstSource.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final Uint8List secondBytes = (await secondSource.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      firstSource.dispose();
      secondSource.dispose();
      return (firstBytes, secondBytes);
    });
    final (Uint8List firstPng, Uint8List secondPng) = pngs!;
    ui.Image? firstDrawn;
    readabilityFrameRenderer =
        (source, {required width, required height, required platform, tint, fixes = const []}) async {
          final ui.Image image = await renderReadabilityFrame(
            source,
            width: width,
            height: height,
            platform: platform,
            tint: tint,
            fixes: fixes,
          );
          firstDrawn ??= image;
          return image;
        };
    try {
      Widget view(Uint8List bytes) => MaterialApp(
        home: SizedBox(
          width: 200,
          height: 400,
          child: ReadabilityFixedImage(provider: MemoryImage(bytes), fixes: const <ReadabilityFix>[]),
        ),
      );
      await tester.pumpWidget(view(firstPng));
      for (int i = 0; i < 20 && firstDrawn == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(firstDrawn, isNotNull);
      expect(firstDrawn!.debugDisposed, isFalse);

      await tester.pumpWidget(view(secondPng));
      expect(firstDrawn!.debugDisposed, isTrue);
    } finally {
      readabilityFrameRenderer = renderReadabilityFrame;
    }
  });

  testWidgets('decodeForFrame bounds both dimensions for a wide source', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(1000, 10, _white);
      final Uint8List png = (await source.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      source.dispose();
      final ui.Image decoded = await decodeForFrame(MemoryImage(png), 100);
      expect(decoded.width, lessThanOrEqualTo(100));
      expect(decoded.height, lessThanOrEqualTo(100));
      decoded.dispose();
    });
  });

  testWidgets('a clock dim darkens the top of a white wall and leaves the bottom alone', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(40, 80, _white);
      final _Decoded out = await _frame(source, width: 40, height: 80, fixes: <ReadabilityFix>[_clockDim]);
      expect(out.pixel(20, 2).$1, lessThan(200));
      expect(out.pixel(20, 78), (255, 255, 255));
    });
  });

  testWidgets('an icons dim darkens the icon area and leaves the top alone', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(40, 80, _white);
      final _Decoded out = await _frame(source, width: 40, height: 80, fixes: <ReadabilityFix>[_iconsDim]);
      expect(out.pixel(20, (0.75 * 80).round()).$1, lessThan(200));
      expect(out.pixel(20, 2).$1, greaterThan(250));
    });
  });

  testWidgets('a blur on a flat grey wall changes no pixel', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(40, 80, const Color(0xFF808080));
      final _Decoded plain = await _frame(source, width: 40, height: 80);
      final _Decoded blurred = await _frame(
        source,
        width: 40,
        height: 80,
        fixes: <ReadabilityFix>[_clockBlur, _iconsBlur],
      );
      for (final (int x, int y) in <(int, int)>[(20, 2), (20, 10), (20, 30), (20, 60), (20, 78)]) {
        final (int, int, int) a = plain.pixel(x, y);
        final (int, int, int) b = blurred.pixel(x, y);
        expect((a.$1 - b.$1).abs(), lessThanOrEqualTo(2), reason: 'red at ($x, $y)');
        expect((a.$2 - b.$2).abs(), lessThanOrEqualTo(2), reason: 'green at ($x, $y)');
        expect((a.$3 - b.$3).abs(), lessThanOrEqualTo(2), reason: 'blue at ($x, $y)');
      }
    });
  });

  testWidgets('renderReadabilityFrame never changes the source image', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _twoHalves(80, 40);
      final ByteData before = (await source.toByteData())!;
      final Uint8List beforeBytes = Uint8List.fromList(before.buffer.asUint8List());
      final ui.Image frame = await renderReadabilityFrame(
        source,
        width: 40,
        height: 80,
        platform: TargetPlatform.android,
        fixes: <ReadabilityFix>[_clockDim, _iconsDim],
      );
      expect(frame.width, 40);
      final ByteData after = (await source.toByteData())!;
      expect(after.buffer.asUint8List(), equals(beforeBytes));
    });
  });

  testWidgets('renderPlacementPng applies a clock dim: top is darker than bottom', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(40, 80, _white);
      final Uint8List png = await renderPlacementPng(
        source,
        const WallpaperPlacement(fixes: <ReadabilityFix>[_clockDim]),
        width: 40,
        height: 80,
        fillColor: _green,
        platform: TargetPlatform.android,
      );
      final _Decoded out = await _decode(png);
      expect(out.image.width, 40);
      expect(out.image.height, 80);
      expect(out.pixel(20, 2).$1, lessThan(out.pixel(20, 78).$1));
      expect(out.pixel(20, 78), (255, 255, 255));
    });
  });

  testWidgets('renderPlacementPng with no fixes keeps the top and bottom equal', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(40, 80, _white);
      final Uint8List png = await renderPlacementPng(
        source,
        const WallpaperPlacement(),
        width: 40,
        height: 80,
        fillColor: _green,
        platform: TargetPlatform.android,
      );
      final _Decoded out = await _decode(png);
      expect(out.pixel(20, 2), out.pixel(20, 78));
    });
  });

  testWidgets('a blue tint changes the centre of a red wall', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(40, 80, _red);
      final _Decoded plain = await _frame(source, width: 40, height: 80);
      final _Decoded tinted = await _frame(source, width: 40, height: 80, tint: const Color(0xFF0000FF));
      expect(tinted.pixel(20, 40), isNot(equals(plain.pixel(20, 40))));
    });
  });

  test('readabilityFixesKey joins each fix key with dashes', () {
    expect(readabilityFixesKey(<ReadabilityFix>[_clockDim, _iconsBlur]), 'read-clock-dim-icons-blur');
  });
}
