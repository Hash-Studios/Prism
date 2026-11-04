import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/crop_frame_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/wait_for_real_io.dart';

Future<List<int>> _png(int width, int height, Color color) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  picture.dispose();
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return data.buffer.asUint8List();
}

Widget _host(String path) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: WallpaperFilterScreen(filePath: path),
);

Future<void> _waitUntilReady(WidgetTester tester) async {
  await waitForRealIo(tester, () {
    final Finder button = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
    return button.evaluate().isNotEmpty && tester.widget<IconButton>(button).onPressed != null;
  }, reason: 'editor source loaded');
}

void main() {
  testWidgets('replacing the source resets crop and reads the new dimensions', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_editor_state_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final List<int> firstBytes = (await tester.runAsync(() => _png(40, 80, Colors.red)))!;
    final List<int> secondBytes = (await tester.runAsync(() => _png(64, 48, Colors.blue)))!;
    final File first = File('${directory.path}/first.png')..writeAsBytesSync(firstBytes);
    final File second = File('${directory.path}/second.png')..writeAsBytesSync(secondBytes);

    await tester.pumpWidget(_host(first.path));
    await _waitUntilReady(tester);
    await tester.tap(find.text('Crop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();
    expect(tester.widget<CropFrameView>(find.byType(CropFrameView)).spec.isIdentity, isFalse);

    await tester.pumpWidget(_host(second.path));
    await _waitUntilReady(tester);
    await tester.pumpAndSettle();

    final CropSpec crop = tester.widget<CropFrameView>(find.byType(CropFrameView)).spec;
    expect(crop.sourceWidth, 64);
    expect(crop.sourceHeight, 48);
    expect(crop.isIdentity, isTrue);
  });
}
