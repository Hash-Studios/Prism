import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  theme: prismLightThemes.first.theme,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Align(alignment: Alignment.topCenter, child: child),
    ),
  ),
);

Widget _directionalHost(Widget child, {required TargetPlatform platform, required TextDirection direction}) =>
    MaterialApp(
      theme: prismLightThemes.first.theme.copyWith(platform: platform),
      home: Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(child: SizedBox(width: 360, child: child)),
          ),
        ),
      ),
    );

double _dy(WidgetTester tester, Finder finder) => tester.getCenter(finder).dy;

void main() {
  for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.iOS]) {
    for (final TextDirection direction in <TextDirection>[TextDirection.ltr, TextDirection.rtl]) {
      for (final int selected in <int>[0, 2]) {
        testWidgets('thumb centers on selected segment for $direction, $platform, index $selected at 2x text', (
          tester,
        ) async {
          await tester.pumpWidget(
            _directionalHost(
              PrismSegmented<int>(
                values: const <int>[0, 1, 2],
                selected: selected,
                labelOf: (value) => <String>['Home', 'Lock', 'Both'][value],
                onChanged: (_) {},
              ),
              platform: platform,
              direction: direction,
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));

          final String selectedLabel = <String>['Home', 'Lock', 'Both'][selected];
          final Finder selectedSegment = find.ancestor(
            of: find.text(selectedLabel),
            matching: find.byType(GestureDetector),
          );
          final Finder thumb = find.descendant(of: find.byType(AnimatedAlign), matching: find.byType(DecoratedBox));
          expect(tester.getCenter(thumb).dx, closeTo(tester.getCenter(selectedSegment).dx, 0.5));
        });
      }
    }
  }

  for (final double scale in <double>[1, 1.5]) {
    testWidgets('segmented labels and icons sit on the vertical centre of the control at $scale x text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PrismSegmented<int>(
            values: const <int>[0, 1, 2],
            selected: 1,
            labelOf: (v) => <String>['Home', 'Lock', 'Both'][v],
            iconOf: (v) => <IconData>[Icons.home_rounded, Icons.lock_rounded, Icons.layers_rounded][v],
            onChanged: (_) {},
          ),
          scale: scale,
        ),
      );

      final double middle = _dy(tester, find.byType(PrismSegmented<int>));
      for (final String label in <String>['Home', 'Lock', 'Both']) {
        expect(_dy(tester, find.text(label)), closeTo(middle, 0.5), reason: label);
      }
      for (final IconData icon in <IconData>[Icons.home_rounded, Icons.lock_rounded, Icons.layers_rounded]) {
        expect(_dy(tester, find.byIcon(icon)), closeTo(middle, 0.5), reason: '$icon');
      }
    });
  }

  testWidgets('chip labels sit on the vertical centre of the chip', (tester) async {
    await tester.pumpWidget(_host(PrismChip(label: 'Aesthetic', selected: true, onTap: () {})));

    expect(_dy(tester, find.text('Aesthetic')), closeTo(_dy(tester, find.byType(PrismChip)), 0.5));
  });
}
