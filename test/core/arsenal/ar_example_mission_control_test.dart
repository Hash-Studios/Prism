import 'package:Prism/core/arsenal/examples/ar_example_mission_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arsenal_test_helpers.dart';

void main() {
  setUpAll(loadArsenalFonts);

  testWidgets('ar_example_mission_control golden', (tester) async {
    await pumpArsenalWidget(tester, const SizedBox(width: 390, height: 844, child: ArExampleMissionControl()));
    await expectLater(
      find.byType(ArExampleMissionControl),
      matchesGoldenFile('goldens/ar_example_mission_control.png'),
    );
  });
}
