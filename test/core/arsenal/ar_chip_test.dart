import 'package:Prism/core/arsenal/components/ar_chip.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arsenal_test_helpers.dart';

void main() {
  setUpAll(loadArsenalFonts);

  testWidgets('ar_chip unselected golden', (tester) async {
    await pumpArsenalWidget(tester, const ArChip(label: 'Cyberpunk'));
    await expectLater(find.byType(ArChip), matchesGoldenFile('goldens/ar_chip_unselected.png'));
  });

  testWidgets('ar_chip selected golden', (tester) async {
    await pumpArsenalWidget(tester, const ArChip(label: 'Cyberpunk', selected: true));
    await expectLater(find.byType(ArChip), matchesGoldenFile('goldens/ar_chip_selected.png'));
  });
}
