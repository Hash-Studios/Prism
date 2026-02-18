import 'package:Prism/core/arsenal/components/ar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arsenal_test_helpers.dart';

void main() {
  setUpAll(loadArsenalFonts);

  testWidgets('ar_button primary golden', (tester) async {
    await pumpArsenalWidget(
      tester,
      SizedBox(
        width: 390,
        child: ArButton.primary(label: 'CONFIRM', onPressed: () {}),
      ),
    );
    await expectLater(find.byType(ArButton), matchesGoldenFile('goldens/ar_button_primary.png'));
  });

  testWidgets('ar_button secondary golden', (tester) async {
    await pumpArsenalWidget(
      tester,
      SizedBox(
        width: 390,
        child: ArButton.secondary(label: 'CONFIRM', onPressed: () {}),
      ),
    );
    await expectLater(find.byType(ArButton), matchesGoldenFile('goldens/ar_button_secondary.png'));
  });

  testWidgets('ar_button ghost golden', (tester) async {
    await pumpArsenalWidget(
      tester,
      SizedBox(
        width: 390,
        child: ArButton.ghost(label: 'CONFIRM', onPressed: () {}),
      ),
    );
    await expectLater(find.byType(ArButton), matchesGoldenFile('goldens/ar_button_ghost.png'));
  });

  testWidgets('ar_button loading golden', (tester) async {
    await pumpArsenalWidget(tester, SizedBox(width: 390, child: ArButton.primary(label: 'CONFIRM', isLoading: true)));
    await expectLater(find.byType(ArButton), matchesGoldenFile('goldens/ar_button_loading.png'));
  });

  testWidgets('ar_button disabled golden', (tester) async {
    await pumpArsenalWidget(tester, SizedBox(width: 390, child: ArButton.primary(label: 'CONFIRM', isDisabled: true)));
    await expectLater(find.byType(ArButton), matchesGoldenFile('goldens/ar_button_disabled.png'));
  });
}
