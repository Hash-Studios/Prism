import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

const List<int> _pngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final int b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);

/// A PNG of [width] x [height] with a tEXt chunk after the header, the way a camera app stores location.
Future<Uint8List> _pngWithMetadata(int width, int height, String text) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
  );
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final Uint8List png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose();
  final List<int> typeAndData = <int>[...ascii.encode('tEXt'), ...latin1.encode(text)];
  final List<int> chunk = <int>[..._u32(typeAndData.length - 4), ...typeAndData, ..._u32(_crc32(typeAndData))];
  const int afterHeader = 8 + 25;
  return Uint8List.fromList(<int>[...png.sublist(0, afterHeader), ...chunk, ...png.sublist(afterHeader)]);
}

Future<ui.Image> _decode(Uint8List bytes) async => (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

void main() {
  testWidgets('a picked image becomes a PNG without its metadata, capped at 2000 px tall', (tester) async {
    await tester.runAsync(() async {
      final Uint8List input = await _pngWithMetadata(600, 4000, 'GPS\u0000lat=12.9716;lon=77.5946');
      expect(latin1.decode(input, allowInvalid: true), contains('lat=12.9716'));

      final Uint8List output = (await screenshotAsPng(input))!;

      expect(output.sublist(0, 8), _pngSignature);
      expect(latin1.decode(output, allowInvalid: true), isNot(contains('lat=12.9716')));
      final ui.Image decoded = await _decode(output);
      expect((decoded.width, decoded.height), (300, 2000));
    });
  });

  testWidgets('a small image keeps its size', (tester) async {
    await tester.runAsync(() async {
      final Uint8List output = (await screenshotAsPng(await _pngWithMetadata(120, 240, 'Comment\u0000hi')))!;

      final ui.Image decoded = await _decode(output);
      expect((decoded.width, decoded.height), (120, 240));
    });
  });
}
