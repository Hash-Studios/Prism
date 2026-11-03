import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/crop_frame_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/wait_for_real_io.dart';

// An 80x40 JPEG with red/green above blue/yellow. Generated once with ffmpeg's mjpeg encoder.
const String _jpeg =
    '/9j/4AAQSkZJRgABAgAAAQABAAD//gAQTGF2YzYwLjMxLjEwMgD/2wBDAAgEBAQEBAUFBQUFBQYGBgYGBgYGBgYGBgYHBwcICAgHBwcGBgcH'
    'CAgICAkJCQgICAgJCQoKCgwMCwsODg4RERT/xACBAAEBAQEBAAAAAAAAAAAAAAAABgUIBwEBAQEBAQEBAQAAAAAAAAAAAAcGBQgDAgEQAQAABwEA'
    'AAAAAAAAAAAAAACj42RlFhfkpBEAAQEDCAYIBgMBAAAAAAAAAAIEAwE1MnJ0sbMFGJQW0RETEhdVVmVkohSjgQcVMTQhCEFRBv/AABEIACgA'
    'UAMBEgACEgADEgD/2gAMAwEAAhEDEQA/AIsZQF/AAAAAAAAAH8VMVRVYFTFUVWHxxGT2urvrtQxGT2urvrtR6SMvGcqkq0RnKpKtPDzV+c'
    '311rvlhq/Ob6613ywAPwAAAAAAAADx/KqOPJY6+ZZo9pHmjJ2lXPT2YWPUC9ITsJwbGVUceSx0oyzR7SPNGTtKuUfMLHqBekJ2E4NjKq'
    'OPJY6UZZo9pHmjJ2lXKPmFj1AvSE7CcGxlVHHksdKMs0e0jzRk7SrlHzCx6gXpCdhODYyqjjyWOkjT/GuLhmfvdY1x5HTxe70yf3ypjH'
    '/SqYnJrbVn92oor/5/xaHLxz9BWnioU73+oh+ueHLv+39bydQnIpJtOn9c3PydKmeIWn/ovTtTQ6izwjw3z1G/m+/KuMN/xOZicpNtZf3ij'
    'kvfkbxnz599d5eM9eP+XgzeKqK93w3m+hNRRTYTOubn5OlTOhrP4bzHIMB0E9/eyb8mdc3PydKmdfWfw3mOQYDoJ7+9k35M65ufk6VM6'
    '+s/hvMcgwHQT397JvyZ1zc/J0qZ19Z/DeY5BgOgnv72TfnHQ9/gy4AAAAAAAAA+GJya21Z/dqGJya21Z/dqEJyKSbRCcikm07FHg7E5Sbay'
    '/vFDE5Sbay/vFGohNRRTYITUUU2AfAAAAAAAAAAH/9k=';

Uint8List _orientation6Jpeg() {
  final Uint8List jpeg = base64Decode(_jpeg);
  // APP1, length 34: Exif + little-endian TIFF, one SHORT orientation (0x0112) entry with value 6.
  const List<int> exif = <int>[
    0xff,
    0xe1,
    0,
    34,
    0x45,
    0x78,
    0x69,
    0x66,
    0,
    0,
    0x49,
    0x49,
    42,
    0,
    8,
    0,
    0,
    0,
    1,
    0,
    0x12,
    1,
    3,
    0,
    1,
    0,
    0,
    0,
    6,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];
  return Uint8List.fromList(<int>[...jpeg.take(2), ...exif, ...jpeg.skip(2)]);
}

class _Pixels {
  const _Pixels(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;

  List<int> at(int x, int y) => rgba.sublist((y * width + x) * 4, (y * width + x) * 4 + 4);
}

Future<_Pixels> _pixels(ui.Image image) async {
  final ByteData data = (await image.toByteData())!;
  return _Pixels(image.width, image.height, data.buffer.asUint8List());
}

Future<_Pixels> _decode(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(await ui.ImmutableBuffer.fromUint8List(bytes));
  try {
    final ui.Image image = (await codec.getNextFrame()).image;
    try {
      return await _pixels(image);
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void _expectSamePixels(_Pixels actual, _Pixels expected) {
  expect((actual.width, actual.height), (expected.width, expected.height));
  expect(actual.rgba, orderedEquals(expected.rgba));
}

void main() {
  testWidgets('EXIF 6 metadata, Image.file, editor crop and export share oriented pixels', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_exif_6_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final Uint8List jpeg = _orientation6Jpeg();
    final File source = File('${directory.path}/orientation6.jpg')..writeAsBytesSync(jpeg);

    await tester.runAsync(() async {
      final _Pixels encoded = await _decode(base64Decode(_jpeg));
      expect((encoded.width, encoded.height), (80, 40), reason: 'JPEG has landscape encoded pixels');
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromFilePath(source.path);
      final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        expect((descriptor.width, descriptor.height), (40, 80), reason: 'metadata used by _readImageSize is oriented');
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }
    });

    final _Pixels oriented = (await tester.runAsync(() => _decode(jpeg)))!;
    expect((oriented.width, oriented.height), (40, 80));
    // Orientation 6 is clockwise: blue/red above yellow/green. Keep samples away from JPEG block edges.
    expect(oriented.at(10, 20), orderedEquals(<Matcher>[closeTo(0, 3), closeTo(0, 3), closeTo(255, 3), equals(255)]));
    expect(oriented.at(30, 20), orderedEquals(<Matcher>[closeTo(255, 3), closeTo(0, 3), closeTo(0, 3), equals(255)]));
    expect(oriented.at(10, 60), orderedEquals(<Matcher>[closeTo(255, 3), closeTo(255, 3), closeTo(0, 3), equals(255)]));
    expect(oriented.at(30, 60), orderedEquals(<Matcher>[closeTo(0, 3), closeTo(255, 3), closeTo(0, 3), equals(255)]));

    await tester.pumpWidget(MaterialApp(home: Image.file(source)));
    await waitForRealIo(
      tester,
      () => tester.widget<RawImage>(find.byType(RawImage)).image != null,
      reason: 'Image.file decoded orientation-6 JPEG',
    );
    final ui.Image displayed = tester.widget<RawImage>(find.byType(RawImage)).image!;
    _expectSamePixels((await tester.runAsync(() => _pixels(displayed)))!, oriented);

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperFilterScreen(filePath: source.path),
      ),
    );
    await waitForRealIo(tester, () {
      final Finder button = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
      return button.evaluate().isNotEmpty && tester.widget<IconButton>(button).onPressed != null;
    }, reason: 'actual editor loaded EXIF source');
    await tester.tap(find.text('Crop'));
    await tester.pumpAndSettle();
    final CropSpec initial = tester.widget<CropFrameView>(find.byType(CropFrameView)).spec;
    expect((initial.sourceWidth, initial.sourceHeight), (40, 80));
    expect(initial.isIdentity, isTrue);
    final Finder preview = find.descendant(of: find.byType(CropFrameView), matching: find.byType(RawImage));
    final ui.Image previewImage = tester.widget<RawImage>(preview).image!;
    _expectSamePixels((await tester.runAsync(() => _pixels(previewImage)))!, oriented);

    await tester.runAsync(() async {
      Future<_Pixels> export(CropSpec crop) async => _decode(
        await renderEditedFile(
          source.path,
          stack: const <WallpaperFilter>[],
          adjustments: WallpaperAdjustments.none,
          crop: crop,
        ),
      );
      final _Pixels uncropped = await export(initial);
      expect((uncropped.width, uncropped.height), (40, 80));
      // Canvas uses FilterQuality.high, which may interpolate at color boundaries even at 1:1. Compare interiors.
      for (final int y in <int>[10, 30, 50, 70]) {
        for (final int x in <int>[10, 30]) {
          expect(uncropped.at(x, y), oriented.at(x, y));
        }
      }
      final CropSpec top = initial.withPreset(CropPreset.square).moved(0, -1000);
      expect(top.sourceRect, const PixelRect(0, 0, 40, 40));
      final _Pixels cropped = await export(top);
      expect((cropped.width, cropped.height), (40, 40));
      for (final int y in <int>[10, 30]) {
        for (final int x in <int>[10, 30]) {
          expect(cropped.at(x, y), oriented.at(x, y));
        }
      }
      final _Pixels turned = await export(top.rotated());
      expect((turned.width, turned.height), (40, 40));
      for (int y = 0; y < 40; y++) {
        for (int x = 0; x < 40; x++) {
          expect(turned.at(39 - y, x), cropped.at(x, y));
        }
      }
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
