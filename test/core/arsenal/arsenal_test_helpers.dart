import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads a .ttf file from disk as [ByteData] for [FontLoader.addFont].
Future<ByteData> _fontFile(String path) async {
  final bytes = File(path).readAsBytesSync();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

/// Loads all Arsenal design-system fonts so golden screenshots render
/// actual glyphs instead of Ahem blocks.
///
/// Call once in [setUpAll] of each test file.
Future<void> loadArsenalFonts() async {
  final bigShoulders = FontLoader('BigShouldersDisplay');
  for (final v in ['Thin', 'ExtraLight', 'Light', 'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
    bigShoulders.addFont(_fontFile('lib/core/arsenal/fonts/BigShouldersDisplay-$v.ttf'));
  }
  await bigShoulders.load();

  final rajdhani = FontLoader('Rajdhani');
  for (final v in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) {
    rajdhani.addFont(_fontFile('lib/core/arsenal/fonts/Rajdhani-$v.ttf'));
  }
  await rajdhani.load();

  final jetBrains = FontLoader('JetBrainsMono');
  for (final v in ['Thin', 'ExtraLight', 'Light', 'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jetBrains.addFont(_fontFile('lib/core/arsenal/fonts/JetBrainsMono-$v.ttf'));
  }
  for (final v in [
    'ThinItalic',
    'ExtraLightItalic',
    'LightItalic',
    'Italic',
    'MediumItalic',
    'SemiBoldItalic',
    'BoldItalic',
    'ExtraBoldItalic',
  ]) {
    jetBrains.addFont(_fontFile('lib/core/arsenal/fonts/JetBrainsMono-$v.ttf'));
  }
  await jetBrains.load();
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
