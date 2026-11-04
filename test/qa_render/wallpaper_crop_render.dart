@Tags(<String>['qa_render'])
library;

import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'qa_harness.dart';

/// The editor's Crop tab on a landscape wall: the frame, two presets, a drag with the grid, and the cropped preview.
void main() {
  setUpAll(() async {
    registerFallbackValue(WallpaperDetailRoute());
    await loadFonts();
  });

  for (final double textScale in <double>[1, 2]) {
    qaScreen('wallpaper crop text x$textScale', (QaShot shot) async {
      final String suffix = textScale == 1 ? '' : '_large_text';
      final Directory directory = Directory.systemTemp.createTempSync('qa_crop_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final File source = File('${directory.path}/source.jpg')
        ..writeAsBytesSync(File('assets/images/onboarding_bg_primary.jpg').readAsBytesSync());
      await shot.pump(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: WallpaperFilterScreen(filePath: source.path),
          ),
        ),
      );
      await shot.settle(frames: 10);
      await shot.tester.tap(find.text('Crop'));
      await shot.settle(frames: 12);
      await shot.save('crop_original$suffix');
      if (textScale != 1) return;
      await shot.tester.tap(find.text('This phone'));
      await shot.settle();
      await shot.save('crop_this_phone');
      await shot.tester.ensureVisible(find.text('16:9 desktop'));
      await shot.tester.tap(find.text('16:9 desktop'));
      await shot.settle();
      final TestGesture drag = await shot.tester.startGesture(
        shot.tester.getCenter(find.bySemanticsLabel('Crop area')),
      );
      await drag.moveBy(const Offset(0, 20));
      await drag.moveBy(const Offset(-40, 10));
      await shot.tester.pump();
      await shot.tester.pump(const Duration(milliseconds: 300));
      await shot.save('crop_drag_grid');
      await drag.up();
      await shot.settle();
      await shot.tester.tap(find.text('Filters'));
      await shot.settle();
      await shot.save('crop_preview_16x9');
    });
  }
}
