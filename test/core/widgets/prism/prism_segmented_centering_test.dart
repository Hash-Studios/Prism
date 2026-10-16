import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
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

double _dy(WidgetTester tester, Finder finder) => tester.getCenter(finder).dy;

void main() {
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
