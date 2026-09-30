import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, TextStyle Function(BuildContext)> styles = <String, TextStyle Function(BuildContext)>{
    'screenTitle': PrismTextStyles.screenTitle,
    'sectionTitle': PrismTextStyles.sectionTitle,
    'sheetHeadline': PrismTextStyles.sheetHeadline,
    'cardTitle': PrismTextStyles.cardTitle,
    'rowTitle': PrismTextStyles.rowTitle,
    'body': PrismTextStyles.body,
    'caption': PrismTextStyles.caption,
    'eyebrow': PrismTextStyles.eyebrow,
    'numeral': (context) => PrismTextStyles.numeral(context, 40),
  };
  final List<ThemeData> themes = <ThemeData>[
    kLightTheme,
    kLightTheme2,
    kLightTheme3,
    kLightTheme4,
    kDarkTheme,
    kDarkTheme2,
    kDarkTheme3,
    kDarkTheme4,
    kDarkTheme5,
    kDarkTheme6,
    kDarkTheme7,
    kDarkTheme8,
  ];

  testWidgets('new text styles stay visible on Prism content surfaces in every theme', (tester) async {
    for (final ThemeData theme in themes) {
      late Map<String, TextStyle> resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: Builder(
            builder: (context) {
              resolved = styles.map((name, style) => MapEntry(name, style(context)));
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      for (final MapEntry<String, TextStyle> entry in resolved.entries) {
        for (final Color background in <Color>[theme.colorScheme.surface, theme.colorScheme.surfaceContainerHigh]) {
          expect(
            _contrastRatio(entry.value.color!, background),
            greaterThanOrEqualTo(3),
            reason: '${entry.key} on $background in ${theme.brightness} theme',
          );
        }
      }
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final Color composited = Color.alphaBlend(foreground, background);
  final double foregroundLuminance = composited.computeLuminance();
  final double backgroundLuminance = background.computeLuminance();
  final double lighter = foregroundLuminance > backgroundLuminance ? foregroundLuminance : backgroundLuminance;
  final double darker = foregroundLuminance > backgroundLuminance ? backgroundLuminance : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
