import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/readability/data/readability_render.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/readability/views/readability_views.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
        Theme(
          data: kLightTheme.copyWith(platform: TargetPlatform.android),
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

    expect(tester.getSize(find.byType(ReadabilityChip)).height, 48.0);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('the readability chip keeps 44 pt on iOS at small text', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
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

  for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.iOS]) {
    for (final Size size in <Size>[const Size(360, 740), const Size(1024, 1366)]) {
      for (final TextDirection direction in TextDirection.values) {
        for (final bool apply in <bool>[true, false]) {
          testWidgets('preview and both actions stay ordered at 2x dark $direction on $platform $size, apply=$apply', (
            tester,
          ) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            readabilityFrameRenderer =
                (
                  source, {
                  required width,
                  required height,
                  required platform,
                  tint,
                  fixes = const <ReadabilityFix>[],
                }) => _solid(width, height);
            final SemanticsHandle semantics = tester.ensureSemantics();
            final ReadabilityPreviewSource source = ReadabilityPreviewSource(
              provider: FileImage(File(_previewPath)),
              screen: size,
              textColor: Colors.white,
            );
            bool? result;
            await tester.pumpWidget(
              a11yApp(
                Theme(
                  data: kDarkTheme.copyWith(platform: platform),
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async => result = await showReadabilityFixSheet(
                        context,
                        source,
                        const ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.dim),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
                variant: A11yVariant(Brightness.dark, 2, direction),
              ),
            );
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
            await _waitUntil(
              tester,
              () => tester.widget<PrismButton>(find.byKey(_applyKey)).onPressed != null,
              reason: 'both previews render before enabling Apply',
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final SemanticsNode before = tester.getSemantics(
              find.bySemanticsLabel(RegExp('Wallpaper without the fix.*Before', dotAll: true)),
            );
            final SemanticsNode after = tester.getSemantics(
              find.bySemanticsLabel(RegExp('Wallpaper with the fix.*After', dotAll: true)),
            );
            final String applyLabel = tester.widget<PrismButton>(find.byKey(_applyKey)).label;
            final String keepLabel = tester
                .widget<PrismButton>(find.byKey(const ValueKey<String>('readability-keep')))
                .label;
            final SemanticsNode applyButton = tester.getSemantics(find.bySemanticsLabel(applyLabel));
            final SemanticsNode keepButton = tester.getSemantics(find.bySemanticsLabel(keepLabel));
            expect(<int>{before.id, after.id, applyButton.id, keepButton.id}, hasLength(4));
            final List<String> traversalLabels = _traversalLabels(before);
            final l10n = tester.element(find.byType(ReadabilityFixSheet)).l10n;
            final int titleIndex = traversalLabels.indexWhere((label) => label.contains(l10n.readabilityDimClockTitle));
            final int messageIndex = traversalLabels.indexWhere((label) => label.contains(l10n.readabilityClockBody));
            final int beforeIndex = traversalLabels.indexWhere((label) => label.contains(before.label));
            final int afterIndex = traversalLabels.indexWhere((label) => label.contains(after.label));
            final int applyIndex = traversalLabels.indexWhere((label) => label.contains(applyLabel));
            final int keepIndex = traversalLabels.indexWhere((label) => label.contains(keepLabel));
            expect(titleIndex, greaterThanOrEqualTo(0), reason: '$traversalLabels');
            expect(messageIndex, greaterThan(titleIndex), reason: '$traversalLabels');
            expect(beforeIndex, greaterThan(messageIndex), reason: '$traversalLabels');
            expect(afterIndex, greaterThan(beforeIndex), reason: '$traversalLabels');
            expect(applyIndex, greaterThan(afterIndex), reason: '$traversalLabels');
            expect(keepIndex, greaterThan(applyIndex), reason: '$traversalLabels');
            for (final SemanticsNode preview in <SemanticsNode>[before, after]) {
              expect(preview.flagsCollection.isImage, isTrue);
              expect(preview.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
            }
            for (final SemanticsNode button in <SemanticsNode>[applyButton, keepButton]) {
              expect(button.flagsCollection.isButton, isTrue);
              expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
              expect(button.rect.height, greaterThanOrEqualTo(platform == TargetPlatform.iOS ? 44 : 48));
            }
            final SemanticsNode target = apply ? applyButton : keepButton;
            target.owner!.performAction(target.id, SemanticsAction.tap);
            await tester.pumpAndSettle();
            expect(result, apply);
            expect(find.byType(ReadabilityFixSheet), findsNothing);
            semantics.dispose();
          });
        }
      }
    }
  }
}

List<String> _traversalLabels(SemanticsNode node) {
  final SemanticsNode? root = node.owner?.rootSemanticsNode;
  if (root == null) return const <String>[];

  Iterable<String> labels(SemanticsNode node) sync* {
    if (node.label.isNotEmpty) yield node.label;
    for (final SemanticsNode child in node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
      yield* labels(child);
    }
  }

  return labels(root).toList();
}
