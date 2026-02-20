import 'package:Prism/core/arsenal/arsenal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arsenal_test_helpers.dart';

void main() {
  setUpAll(loadArsenalFonts);

  testWidgets('ar_app_bar_title_only golden', (tester) async {
    await pumpArsenalWidget(
      tester,
      const SizedBox(
        width: 390,
        height: 120,
        child: ArAppBar(title: 'Arsenal', showBackButton: false),
      ),
    );
    await expectLater(find.byType(ArAppBar), matchesGoldenFile('goldens/ar_app_bar_title_only.png'));
  });

  testWidgets('ar_app_bar_with_action golden', (tester) async {
    await pumpArsenalWidget(
      tester,
      const SizedBox(
        width: 390,
        height: 120,
        child: ArAppBar(
          title: 'Arsenal',
          showBackButton: false,
          action: ArTag(label: 'SIGNAL: STABLE'),
        ),
      ),
    );
    await expectLater(find.byType(ArAppBar), matchesGoldenFile('goldens/ar_app_bar_with_action.png'));
  });

  testWidgets('ar_app_bar_with_bottom golden', (tester) async {
    await pumpArsenalWidget(
      tester,
      SizedBox(
        width: 390,
        height: 160,
        child: ArAppBar(
          title: 'Arsenal',
          showBackButton: false,
          action: const ArTag(label: 'SIGNAL: STABLE'),
          bottom: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                ArChip(label: 'All'),
                SizedBox(width: 8),
                ArChip(label: 'Wallpapers'),
                SizedBox(width: 8),
                ArChip(label: 'Setups'),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(ArAppBar), matchesGoldenFile('goldens/ar_app_bar_with_bottom.png'));
  });
}
