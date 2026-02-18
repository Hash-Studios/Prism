import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Disables google_fonts HTTP fetching so tests are deterministic.
/// Fonts are loaded from test/core/arsenal/fonts/ via the asset bundle
/// (declared in pubspec.yaml under flutter.assets).
///
/// Call once in [setUpAll] of each test file.
Future<void> loadArsenalFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Pumps [widget] inside a fixed 390×844 logical-pixel surface with
/// the Arsenal dark theme applied. Matches the iPhone 14 logical resolution.
Future<void> pumpArsenalWidget(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;

  await tester.pumpWidget(
    MaterialApp(
      theme: arsenalDarkTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: ArsenalColors.background,
        body: Center(child: widget),
      ),
    ),
  );
  // Use pump instead of pumpAndSettle to avoid timing out on infinite
  // animations (e.g. CircularProgressIndicator in loading states).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
