import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/core/widgets/prism/prism_field.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/moods/views/widgets/mood_chip_row.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
}
