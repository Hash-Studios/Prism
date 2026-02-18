import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/components/ar_tag.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arsenal_test_helpers.dart';

void main() {
  setUpAll(loadArsenalFonts);

  testWidgets('ar_tag default accent golden', (tester) async {
    await pumpArsenalWidget(tester, const ArTag(label: 'Arsenal'));
    await expectLater(find.byType(ArTag), matchesGoldenFile('goldens/ar_tag.png'));
  });

  testWidgets('ar_tag custom color golden', (tester) async {
    await pumpArsenalWidget(tester, const ArTag(label: 'Error', color: ArsenalColors.error));
    await expectLater(find.byType(ArTag), matchesGoldenFile('goldens/ar_tag_custom_color.png'));
  });
}
