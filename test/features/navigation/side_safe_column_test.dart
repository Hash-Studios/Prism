import 'package:Prism/core/utils/side_safe_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<double> _widthFor(WidgetTester tester, {required Size size, required EdgeInsets viewPadding}) async {
  var width = -1.0;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, viewPadding: viewPadding),
      child: Builder(
        builder: (context) {
          width = sideSafeColumnWidth(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return width;
}

void main() {
  testWidgets('iOS: only a portrait screen with a right column and no top inset has a side column', (tester) async {
    // iPhone Duo outer screen.
    expect(await _widthFor(tester, size: const Size(466, 678), viewPadding: const EdgeInsets.only(right: 84)), 84);
    // A portrait screen with a status bar on top, even with a right inset.
    expect(
      await _widthFor(tester, size: const Size(820, 1180), viewPadding: const EdgeInsets.only(top: 24, right: 20)),
      0,
    );
    // Landscape.
    expect(await _widthFor(tester, size: const Size(678, 466), viewPadding: const EdgeInsets.only(right: 84)), 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('other platforms never have a side column', (tester) async {
    expect(await _widthFor(tester, size: const Size(466, 678), viewPadding: const EdgeInsets.only(right: 84)), 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
