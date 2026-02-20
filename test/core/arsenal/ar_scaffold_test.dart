import 'package:Prism/core/arsenal/arsenal.dart';
import 'package:Prism/core/arsenal/colors.dart';
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
            child: Text('ARSENAL', style: TextStyle(color: ArsenalColors.onBackground, fontSize: 24, letterSpacing: 4)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(ArScaffold), matchesGoldenFile('goldens/ar_scaffold.png'));
  });

  testWidgets('ar_scaffold_with_app_bar_and_nav golden', (tester) async {
    final navItems = [
      ArNavItem(icon: Icons.archive_outlined, label: 'Archive', onTap: () {}),
      ArNavItem(icon: Icons.hub_outlined, label: 'Network', onTap: () {}),
      ArNavItem(icon: Icons.upload_outlined, label: 'Upload', onTap: () {}),
      ArNavItem(icon: Icons.person_outline, label: 'Profile', onTap: () {}),
    ];
    await pumpArsenalWidget(
      tester,
      SizedBox(
        width: 390,
        height: 844,
        child: ArScaffold(
          appBar: const ArAppBar(title: 'Arsenal', showBackButton: false),
          navBar: ArBottomNav(items: navItems, activeIndex: 0),
          child: const Center(
            child: Text('BODY', style: TextStyle(color: ArsenalColors.onBackground, fontSize: 24, letterSpacing: 4)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(ArScaffold), matchesGoldenFile('goldens/ar_scaffold_with_app_bar_and_nav.png'));
  });
}
