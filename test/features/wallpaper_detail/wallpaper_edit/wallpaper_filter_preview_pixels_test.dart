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
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/wait_for_real_io.dart';

class _Pixels {
  const _Pixels(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;

  int channel(int x, int y, int channel) => rgba[(y * width + x) * 4 + channel];
}

Future<_Pixels> _pixels(ui.Image image) async {
  final ByteData data = (await image.toByteData())!;
  return _Pixels(image.width, image.height, data.buffer.asUint8List());
}

Future<Uint8List> _sourcePng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Paint paint = Paint()..isAntiAlias = false;
  // Odd dimensions and a different gradient on each axis expose swapped axes, turns and crop offsets.
  for (int y = 0; y < 97; y++) {
    for (int x = 0; x < 131; x++) {
      paint.color = Color.fromARGB(255, 20 + x + y ~/ 3, 15 + 2 * y, 220 - x + y ~/ 4);
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
    }
  }
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(131, 97);
  try {
    final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  testWidgets('the cropped preview shows the exported pixels for every quarter turn', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_preview_pixels_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final Uint8List source = (await tester.runAsync(_sourcePng))!;
    final File file = File('${directory.path}/source.png')..writeAsBytesSync(source);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperFilterScreen(filePath: file.path),
      ),
    );
    await waitForRealIo(tester, () {
      final Finder button = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
      return button.evaluate().isNotEmpty && tester.widget<IconButton>(button).onPressed != null;
    }, reason: 'source image decoded and preview painted');
    await tester.pumpAndSettle();

    CropSpec crop = CropSpec.initial(
      sourceWidth: 131,
      sourceHeight: 97,
      phoneAspect: 2 / 3,
    ).withPreset(CropPreset.free).resized(CropCorner.topLeft, 17, 11).resized(CropCorner.bottomRight, -29, -23);
    for (int turn = 0; turn < 4; turn++) {
      await tester.tap(find.text('Crop'));
      await tester.pumpAndSettle();
      tester.widget<CropFrameView>(find.byType(CropFrameView)).onChanged(crop);
      await tester.pumpAndSettle();
      expect(crop.rect.left, greaterThan(0));
      expect(crop.rect.top, greaterThan(0));
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      final Finder preview = find.descendant(
        of: find.byWidgetPredicate((widget) => widget is GestureDetector && widget.onLongPressStart != null),
        matching: find.byType(RepaintBoundary),
      );
      expect(preview, findsOneWidget);
      final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(preview);
      final ({_Pixels preview, _Pixels export}) captured = (await tester.runAsync(() async {
        final ui.Image previewImage = await boundary.toImage();
        try {
          final Uint8List exported = await renderEditedFile(
            file.path,
            stack: const <WallpaperFilter>[],
            adjustments: WallpaperAdjustments.none,
            crop: crop,
          );
          final ui.Codec codec = await ui.instantiateImageCodec(exported);
          try {
            final ui.Image exportImage = (await codec.getNextFrame()).image;
            try {
              return (preview: await _pixels(previewImage), export: await _pixels(exportImage));
            } finally {
              exportImage.dispose();
            }
          } finally {
            codec.dispose();
          }
        } finally {
          previewImage.dispose();
        }
      }))!;
      expect(captured.export.width, turn.isEven ? 85 : 63);
      expect(captured.export.height, turn.isEven ? 63 : 85);

      // Sample inside the rounded corners, at matching pixel-centre positions. The preview is bilinearly enlarged.
      for (final Offset point in const <Offset>[
        Offset(0.15, 0.20),
        Offset(0.77, 0.21),
        Offset(0.23, 0.74),
        Offset(0.79, 0.82),
        Offset(0.51, 0.47),
      ]) {
        final int exportX = (point.dx * captured.export.width).floor();
        final int exportY = (point.dy * captured.export.height).floor();
        final int previewX = ((exportX + 0.5) / captured.export.width * captured.preview.width).floor();
        final int previewY = ((exportY + 0.5) / captured.export.height * captured.preview.height).floor();
        for (int channel = 0; channel < 4; channel++) {
          expect(
            captured.preview.channel(previewX, previewY, channel),
            closeTo(captured.export.channel(exportX, exportY, channel), 3),
            reason: 'turn $turn, sample $point, RGBA channel $channel',
          );
        }
      }
      crop = crop.rotated();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
