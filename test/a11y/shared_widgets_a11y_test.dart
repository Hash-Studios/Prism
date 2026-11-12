import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/core/widgets/prism/prism_field.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/moods/views/widgets/mood_chip_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/a11y_guidelines.dart';

/// [kLightTheme] fixes its platform when it is built, so an iOS case needs its own theme.
Widget _iosApp(Widget home) => a11yApp(
  Theme(
    data: kLightTheme.copyWith(platform: TargetPlatform.iOS),
    child: home,
  ),
);

void main() {
  setUp(() => PrismDeviceCornerRadius.setValueForTesting(48));

  testWidgets('PrismChip meets the Android and iOS tap target guidelines in every theme, text size and direction', (
    tester,
  ) async {
    await expectA11yGuidelines(
      tester,
      () => Scaffold(
        body: Center(
          child: Wrap(
            children: <Widget>[
              PrismChip(label: 'Red', onTap: () {}),
              PrismChip(label: 'Blue', compact: true, onTap: () {}),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('PrismChip is 48 dp tall on Android and keeps a 44 pt pill', (tester) async {
    await tester.pumpWidget(
      a11yApp(
        Scaffold(
          body: Center(
            child: PrismChip(label: 'Red', onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PrismChip)).height, 48.0);
    final Finder pill = find.descendant(of: find.byType(PrismChip), matching: find.byType(AnimatedContainer));
    expect(tester.getSize(pill).height, 44.0);
  });

  testWidgets('PrismChip stays 44 pt tall on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        _iosApp(
          Scaffold(
            body: Center(
              child: PrismChip(label: 'Red', onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PrismChip)).height, 44.0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('compact PrismChip has a 48 dp tap area on Android and 44 on iOS', (tester) async {
    await tester.pumpWidget(
      a11yApp(
        Scaffold(
          body: Center(
            child: PrismChip(label: 'Red', compact: true, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PrismChip)).height, 48.0);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        _iosApp(
          Scaffold(
            body: Center(
              child: PrismChip(label: 'Red', compact: true, onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PrismChip)).height, 44.0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the sheet close button has a 48 dp tap area on Android', (tester) async {
    await tester.pumpWidget(
      a11yApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPrismSheet<void>(context, builder: (_) => const PrismSheetBody(title: 'Sort by')),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final SemanticsHandle semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester.getSemantics(find.byTooltip('Close')).rect.width, greaterThanOrEqualTo(48));
    semantics.dispose();
  });

  for (final String dimension in <String>['width', 'height']) {
    testWidgets('the sheet trailing action has a 48 dp hit target $dimension on Android', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        a11yApp(
          Theme(
            data: kLightTheme.copyWith(platform: TargetPlatform.android),
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPrismSheet<void>(
                  context,
                  builder: (_) => PrismSheetBody(
                    title: 'Filters',
                    trailingAction: PrismSheetAction(label: 'X', onTap: () {}),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final Rect target = tester.getSemantics(find.bySemanticsLabel('X')).rect;
      expect(dimension == 'width' ? target.width : target.height, greaterThanOrEqualTo(48));
      semantics.dispose();
    });
  }

  testWidgets('the sheet trailing action can be activated by a screen reader', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int taps = 0;
    await tester.pumpWidget(
      a11yApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPrismSheet<void>(
              context,
              builder: (_) => PrismSheetBody(
                title: 'Filters',
                trailingAction: PrismSheetAction(label: 'Reset', onTap: () => taps++),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.bySemanticsLabel('Reset'));
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, ui.SemanticsAction.tap);
    await tester.pump();
    expect(taps, 1);
    expect(find.text('Filters'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the sheet trailing action keeps a 44 pt target on iOS', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme.copyWith(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPrismSheet<void>(
              context,
              builder: (_) => PrismSheetBody(
                title: 'Filters',
                trailingAction: PrismSheetAction(label: 'X', onTap: () {}),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final Rect target = tester.getSemantics(find.bySemanticsLabel('X')).rect;
    expect(target.width, greaterThanOrEqualTo(44));
    expect(target.height, greaterThanOrEqualTo(44));
    expect(target.width, lessThan(48));
    expect(target.height, lessThan(48));
    semantics.dispose();
  });

  testWidgets('sheet header screen-reader order stays close, title, action in LTR and RTL', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    for (final TextDirection direction in TextDirection.values) {
      await tester.pumpWidget(
        a11yApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showPrismSheet<void>(
                context,
                builder: (_) => PrismSheetBody(
                  title: 'Filters',
                  trailingAction: PrismSheetAction(label: 'Reset', onTap: () {}),
                ),
              ),
              child: const Text('open'),
            ),
          ),
          variant: A11yVariant(Brightness.light, 1, direction),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final List<String> labels = _semanticsTraversalLabels(tester);
      final int closeIndex = labels.indexOf('Close');
      final int titleIndex = labels.indexOf('Filters');
      final int actionIndex = labels.indexOf('Reset');
      expect(closeIndex, greaterThanOrEqualTo(0), reason: '$direction: $labels');
      expect(closeIndex, lessThan(titleIndex), reason: '$direction: $labels');
      expect(titleIndex, lessThan(actionIndex), reason: '$direction: $labels');
      expect(tester.getSemantics(find.byTooltip('Close')).getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Reset')).getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
    semantics.dispose();
  });

  testWidgets('sheet trailing actions stay legible and keep the title centered at 2x text in both directions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    for (final TextDirection direction in TextDirection.values) {
      for (final (String, String) sheetCase in <(String, String)>[
        ('Filters', 'Clear all'),
        ('Tune your feed', 'Reset'),
        ('Sort and filter', 'Zurücksetzen'),
      ]) {
        final (String title, String label) = sheetCase;
        await tester.pumpWidget(
          a11yApp(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showPrismSheet<void>(
                  context,
                  builder: (_) => PrismSheetBody(
                    title: title,
                    trailingAction: PrismSheetAction(label: label, onTap: () {}),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
            variant: A11yVariant(Brightness.light, 2, direction),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$direction / $label');
        final Finder actionFinder = find.text(label);
        final Rect target = tester.getSemantics(find.bySemanticsLabel(label)).rect;
        expect(target.width, greaterThanOrEqualTo(48), reason: '$direction / $label');
        expect(target.height, greaterThanOrEqualTo(48), reason: '$direction / $label');
        expect(tester.getRect(find.text(title)).center.dx, closeTo(160, 0.5), reason: '$direction / $title / $label');
        final RenderParagraph action = tester.renderObject<RenderParagraph>(actionFinder);
        expect(action.didExceedMaxLines, isFalse, reason: '$direction / $label');
        final List<TextBox> glyphs = <TextBox>[
          for (int index = 0; index < label.length; index++)
            if (label[index] != ' ')
              ...action.getBoxesForSelection(TextSelection(baseOffset: index, extentOffset: index + 1)),
        ];
        expect(glyphs, isNotEmpty, reason: '$direction / $label');
        final Rect sheet = tester.getRect(find.byType(PrismSheetBody));
        final Rect actionRect = tester.getRect(actionFinder);
        for (final TextBox glyph in glyphs) {
          final Offset topLeft = action.localToGlobal(Offset(glyph.left, glyph.top));
          final Offset bottomRight = action.localToGlobal(Offset(glyph.right, glyph.bottom));
          expect(topLeft.dx, greaterThanOrEqualTo(sheet.left), reason: '$direction / $title / $label');
          expect(bottomRight.dx, lessThanOrEqualTo(sheet.right), reason: '$direction / $title / $label');
          expect(topLeft.dx, greaterThanOrEqualTo(actionRect.left), reason: '$direction / $title / $label');
          expect(bottomRight.dx, lessThanOrEqualTo(actionRect.right), reason: '$direction / $title / $label');
          expect(topLeft.dy, greaterThanOrEqualTo(actionRect.top), reason: '$direction / $title / $label');
          expect(bottomRight.dy, lessThanOrEqualTo(actionRect.bottom), reason: '$direction / $title / $label');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('PrismTextField puts its label at the start edge in RTL', (tester) async {
    await tester.pumpWidget(
      a11yApp(
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: PrismTextField(label: 'Folder name'),
          ),
        ),
        variant: const A11yVariant(Brightness.light, 1, TextDirection.rtl),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopRight(find.text('Folder name')).dx, tester.getTopRight(find.byType(TextField)).dx - 16);
  });

  testWidgets('PrismTextField puts its label at the start edge in LTR', (tester) async {
    await tester.pumpWidget(
      a11yApp(
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: PrismTextField(label: 'Folder name'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Folder name')).dx, tester.getTopLeft(find.byType(TextField)).dx + 16);
  });

  testWidgets('a chip row is tall enough for a 48 dp chip on Android, so the pill keeps its size', (tester) async {
    await tester.pumpWidget(
      a11yApp(
        Scaffold(
          body: MoodChipRow(
            moods: const [],
            leading: PrismChip(label: 'Week', compact: true, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PrismChip)).height, 48.0);
    final Finder pill = find.descendant(of: find.byType(PrismChip), matching: find.byType(AnimatedContainer));
    expect(tester.getSize(pill).height, 34.0);
  });

  testWidgets('the sheet close button sits at the start edge in LTR and in RTL', (tester) async {
    final Map<TextDirection, double> inset = <TextDirection, double>{};
    for (final TextDirection direction in TextDirection.values) {
      await tester.pumpWidget(
        a11yApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showPrismSheet<void>(
                context,
                builder: (_) => PrismSheetBody(
                  title: 'Filters',
                  trailingAction: PrismSheetAction(label: 'Reset all filters', onTap: () {}),
                ),
              ),
              child: const Text('open'),
            ),
          ),
          variant: A11yVariant(Brightness.light, 1, direction),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final Rect sheet = tester.getRect(find.byType(PrismSheetBody));
      final Rect close = tester.getRect(find.byTooltip('Close'));
      inset[direction] = direction == TextDirection.ltr ? close.left - sheet.left : sheet.right - close.right;
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(inset[TextDirection.rtl], inset[TextDirection.ltr]);
  });
}

List<String> _semanticsTraversalLabels(WidgetTester tester) {
  final SemanticsNode? root = tester.getSemantics(find.byTooltip('Close')).owner?.rootSemanticsNode;
  if (root == null) return const <String>[];

  Iterable<String> labels(SemanticsNode node) sync* {
    final String label = node.label.isNotEmpty ? node.label : node.getSemanticsData().tooltip;
    if (label.isNotEmpty) yield label;
    for (final SemanticsNode child in node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
      yield* labels(child);
    }
  }

  return labels(root).toList();
}
