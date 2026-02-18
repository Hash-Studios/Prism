import 'package:Prism/core/arsenal/components/ar_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arsenal_test_helpers.dart';

void main() {
  setUpAll(loadArsenalFonts);

  testWidgets('ar_avatar initials golden', (tester) async {
    await pumpArsenalWidget(tester, const ArAvatar(initials: 'AB'));
    await expectLater(find.byType(ArAvatar), matchesGoldenFile('goldens/ar_avatar_initials.png'));
  });

  testWidgets('ar_avatar fallback golden', (tester) async {
    // No imageUrl and no initials → person icon fallback.
    await pumpArsenalWidget(tester, const ArAvatar());
    await expectLater(find.byType(ArAvatar), matchesGoldenFile('goldens/ar_avatar_fallback.png'));
  });
}
