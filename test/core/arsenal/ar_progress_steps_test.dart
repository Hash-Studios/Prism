import 'package:Prism/core/arsenal/components/ar_progress_steps.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arsenal_test_helpers.dart';

void main() {
  setUpAll(loadArsenalFonts);

  testWidgets('ar_progress_steps golden', (tester) async {
    await pumpArsenalWidget(tester, const ArProgressSteps(total: 4, current: 0));
    await expectLater(
      find.byType(ArProgressSteps),
      matchesGoldenFile('goldens/ar_progress_steps.png'),
    );
  });
}
