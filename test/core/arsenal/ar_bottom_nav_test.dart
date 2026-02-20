import 'package:Prism/core/arsenal/arsenal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arsenal_test_helpers.dart';

final _items = [
  ArNavItem(icon: Icons.archive_outlined, label: 'Archive', onTap: () {}),
  ArNavItem(icon: Icons.hub_outlined, label: 'Network', onTap: () {}),
  ArNavItem(icon: Icons.upload_outlined, label: 'Upload', onTap: () {}),
  ArNavItem(icon: Icons.person_outline, label: 'Profile', onTap: () {}),
];

void main() {
  setUpAll(loadArsenalFonts);

  testWidgets('ar_bottom_nav_index_0 golden', (tester) async {
    await pumpArsenalWidget(
      tester,
      SizedBox(
        width: 390,
        child: ArBottomNav(items: _items, activeIndex: 0),
      ),
    );
    await expectLater(find.byType(ArBottomNav), matchesGoldenFile('goldens/ar_bottom_nav_index_0.png'));
  });

  testWidgets('ar_bottom_nav_index_2 golden', (tester) async {
    await pumpArsenalWidget(
      tester,
      SizedBox(
        width: 390,
        child: ArBottomNav(items: _items, activeIndex: 2),
      ),
    );
    await expectLater(find.byType(ArBottomNav), matchesGoldenFile('goldens/ar_bottom_nav_index_2.png'));
  });
}
