import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_position/data/placement_renderer.dart';
import 'package:Prism/features/wallpaper_position/data/repositories/wallpaper_position_repository_impl.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _blue = Color(0xFF0000FF);
const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);

Future<ui.Image> _image(int width, int height, void Function(Canvas canvas, Size size) paint) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
  return recorder.endRecording().toImage(width, height);
}

Future<ui.Image> _solid(int width, int height, Color color) =>
    _image(width, height, (canvas, size) => canvas.drawRect(Offset.zero & size, Paint()..color = color));

/// Left half blue, right half red.
Future<ui.Image> _twoHalves(int width, int height) => _image(width, height, (canvas, size) {
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 2, size.height), Paint()..color = _blue);
  canvas.drawRect(Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height), Paint()..color = _red);
});

class _Decoded {
  _Decoded(this.image, this.data);

  final ui.Image image;
  final ByteData data;

  (int, int, int) pixel(int x, int y) {
    final int offset = (y * image.width + x) * 4;
    return (data.getUint8(offset), data.getUint8(offset + 1), data.getUint8(offset + 2));
  }

  double get mean {
    double total = 0;
    for (int i = 0; i < image.width * image.height; i++) {
      total += data.getUint8(i * 4) + data.getUint8(i * 4 + 1) + data.getUint8(i * 4 + 2);
    }
    return total / (image.width * image.height * 3);
  }
}

Future<_Decoded> _decode(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  return _Decoded(image, (await image.toByteData())!);
}

Future<_Decoded> _render(
  ui.Image source,
  WallpaperPlacement placement, {
  int width = 20,
  int height = 40,
  Color fill = _green,
}) async => _decode(await renderPlacementPng(source, placement, width: width, height: height, fillColor: fill));

void main() {
  testWidgets('the PNG has exactly the requested size', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(40, 80, _red);
      final _Decoded out = await _render(source, const WallpaperPlacement(), width: 27, height: 53);
      expect((out.image.width, out.image.height), (27, 53));
    });
  });

  testWidgets('fill covers the whole frame and crops a wide wall to its middle', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _twoHalves(80, 40);
      final _Decoded out = await _render(source, const WallpaperPlacement());
      expect(out.pixel(2, 2), (0, 0, 255));
      expect(out.pixel(17, 37), (255, 0, 0));
      expect(out.pixel(10, 20).$1 + out.pixel(10, 20).$3, greaterThan(200));
    });
  });

  testWidgets('dx moves a wide wall: -1 shows its left part and 1 shows its right part', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _twoHalves(80, 40);
      final _Decoded left = await _render(source, const WallpaperPlacement(dx: -1));
      final _Decoded right = await _render(source, const WallpaperPlacement(dx: 1));
      expect(left.pixel(10, 20), (0, 0, 255));
      expect(left.pixel(18, 38), (0, 0, 255));
      expect(right.pixel(10, 20), (255, 0, 0));
      expect(right.pixel(2, 2), (255, 0, 0));
    });
  });

  testWidgets('zoom magnifies the part chosen by dx', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _twoHalves(20, 40);
      final _Decoded left = await _render(source, const WallpaperPlacement(zoom: 2, dx: -1));
      final _Decoded right = await _render(source, const WallpaperPlacement(zoom: 2, dx: 1));
      expect(left.pixel(18, 20), (0, 0, 255));
      expect(right.pixel(2, 20), (255, 0, 0));
    });
  });

  testWidgets('fit with colour shows the whole wall over the fill colour', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(80, 40, _red);
      final _Decoded out = await _render(source, const WallpaperPlacement(fit: PlacementFit.fitColor));
      expect(out.pixel(10, 3), (0, 255, 0));
      expect(out.pixel(10, 20), (255, 0, 0));
      expect(out.pixel(10, 37), (0, 255, 0));
    });
  });

  testWidgets('fit with blur fills the bars from the wall itself, not black or the fill colour', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(80, 40, _red);
      final _Decoded out = await _render(source, const WallpaperPlacement(fit: PlacementFit.fitBlur));
      final (int r, int g, int b) = out.pixel(10, 3);
      expect(r, greaterThan(200));
      expect(g, lessThan(40));
      expect(b, lessThan(40));
      expect(out.pixel(10, 20), (255, 0, 0));
    });
  });

  testWidgets('dim darkens the mean pixel in proportion', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(40, 80, const Color(0xFFFFFFFF));
      final double none = (await _render(source, const WallpaperPlacement())).mean;
      final double half = (await _render(source, const WallpaperPlacement(dim: 0.5))).mean;
      final double most = (await _render(source, const WallpaperPlacement(dim: 0.6))).mean;
      expect(none, closeTo(255, 1));
      expect(half, lessThan(none));
      expect(half, closeTo(127, 3));
      expect(most, lessThan(half));
    });
  });

  testWidgets('dim is drawn over the fill bars as well', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(80, 40, _red);
      final _Decoded out = await _render(
        source,
        const WallpaperPlacement(fit: PlacementFit.fitColor, dim: 0.5),
        fill: const Color(0xFFFFFFFF),
      );
      expect(out.pixel(10, 3).$1, closeTo(127, 3));
    });
  });

  testWidgets('dominantColorOf reads the main colour of a wall', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _solid(300, 300, _blue);
      final Color color = await dominantColorOf(source);
      expect(color.b, greaterThan(0.9));
      expect(color.r, lessThan(0.1));
    });
  });

  testWidgets('decodeCapped keeps a small image and shrinks a huge one to the export cap', (tester) async {
    await tester.runAsync(() async {
      final ui.Image small = await _solid(64, 32, _red);
      final ByteData smallPng = (await small.toByteData(format: ui.ImageByteFormat.png))!;
      final ui.Image decodedSmall = await decodeCapped(smallPng.buffer.asUint8List());
      expect((decodedSmall.width, decodedSmall.height), (64, 32));

      final ui.Image wide = await _solid(5000, 100, _red);
      final ByteData widePng = (await wide.toByteData(format: ui.ImageByteFormat.png))!;
      final ui.Image decodedWide = await decodeCapped(widePng.buffer.asUint8List());
      expect(decodedWide.width, 4096);
      expect(decodedWide.height, closeTo(82, 1));
    });
  });
}
