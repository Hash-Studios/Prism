import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/readability/data/readability_render.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/readability/views/readability_views.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/a11y_guidelines.dart';

final String _previewPath = File('assets/images/prism.webp').absolute.path;

const ValueKey<String> _applyKey = ValueKey<String>('readability-apply');

/// A flat grey frame in place of the real painter, so the sheet gets its images without a render.
Future<ui.Image> _solid(int width, int height) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(Offset.zero & Size(width.toDouble(), height.toDouble()), Paint()..color = const Color(0xFF808080));
  return recorder.endRecording().toImage(width, height);
}

/// Lets the real event loop run image decodes, then draws a frame. Stops early when [done] is true.
Future<void> _waitUntil(WidgetTester tester, bool Function() done, {required String reason}) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  expect(done(), isTrue, reason: reason);
}

void main() {
  setUp(() {
    readabilityFrameRenderer = renderReadabilityFrame;
  });

  tearDown(() {
    readabilityFrameRenderer = renderReadabilityFrame;
  });

  testWidgets('the readability chip has a 48 dp tap area on Android at small text', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      a11yApp(
        Scaffold(
          body: Center(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 0.5,
              child: ReadabilityChip(zone: ReadabilityZone.clock, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ReadabilityChip)).height, 48.0);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('the readability chip keeps 44 pt on iOS at small text', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final SemanticsHandle semantics = tester.ensureSemantics();
      // The app theme keeps the platform it was built with, so the iOS override also goes on the theme.
      await tester.pumpWidget(
        a11yApp(
          Theme(
            data: kLightTheme.copyWith(platform: TargetPlatform.iOS),
            child: Scaffold(
              body: Center(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 0.5,
                  child: ReadabilityChip(zone: ReadabilityZone.clock, onTap: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(ReadabilityChip)).height, 44.0);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the readability chip meets every guideline in light and dark, 1x and 2x text, LTR and RTL', (
    tester,
  ) async {
    await expectA11yGuidelines(
      tester,
      () => Scaffold(
        body: Center(
          child: ReadabilityChip(zone: ReadabilityZone.icons, onTap: () {}),
        ),
      ),
    );
  });

  testWidgets('each readability preview reads as one item with its caption', (tester) async {
    readabilityFrameRenderer =
        (source, {required width, required height, required platform, tint, fixes = const <ReadabilityFix>[]}) =>
            _solid(width, height);
    final SemanticsHandle semantics = tester.ensureSemantics();
    final ReadabilityPreviewSource source = ReadabilityPreviewSource(
      provider: FileImage(File(_previewPath)),
      screen: const Size(390, 844),
      textColor: Colors.white,
    );
    const ReadabilityFix fix = ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.dim);
    await tester.pumpWidget(
      a11yApp(
        Builder(
          builder: (context) =>
              TextButton(onPressed: () => showReadabilityFixSheet(context, source, fix), child: const Text('open')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _waitUntil(
      tester,
      () => tester.widget<PrismButton>(find.byKey(_applyKey)).onPressed != null,
      reason: 'the after preview renders and Apply enables',
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Wallpaper without the fix.*Before', dotAll: true)), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Wallpaper with the fix.*After', dotAll: true)), findsOneWidget);
    semantics.dispose();
  });
}
