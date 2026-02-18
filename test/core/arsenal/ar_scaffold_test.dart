import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/components/ar_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arsenal_test_helpers.dart';

void main() {
  setUpAll(loadArsenalFonts);

  testWidgets('ar_scaffold golden', (tester) async {
    await pumpArsenalWidget(
      tester,
      const SizedBox(
        width: 390,
        height: 844,
        child: ArScaffold(
          child: Center(
            child: Text(
              'ARSENAL',
              style: TextStyle(
                color: ArsenalColors.onBackground,
                fontSize: 24,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(ArScaffold), matchesGoldenFile('goldens/ar_scaffold.png'));
  });
}
