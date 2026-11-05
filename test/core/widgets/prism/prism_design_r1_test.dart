import 'package:Prism/core/widgets/cosmetics/glow_text.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme ?? kLightTheme,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Align(alignment: Alignment.topCenter, child: child),
    ),
  ),
);

Color _onBlend(Color over, Color base, double alpha) => Color.alphaBlend(over.withValues(alpha: alpha), base);

void main() {
  group('colour scheme', () {
    test('light cards are a softer grey, dark cards keep 8 percent', () {
      final ColorScheme light = kLightTheme.colorScheme;
      expect(light.surfaceContainerHigh, _onBlend(light.onSurface, light.surface, 0.045));
      final ColorScheme dark = kDarkTheme.colorScheme;
      expect(dark.surfaceContainerHigh, _onBlend(dark.onSurface, dark.surface, 0.08));
    });

    test('light sheets use the page colour; dark and Material You keep surfaceContainerLow', () {
      for (final PrismThemeOption option in prismLightThemes.where((o) => o.usesAccent)) {
        final ThemeData theme = option.theme;
        expect(theme.bottomSheetTheme.modalBackgroundColor, theme.colorScheme.surface, reason: option.id);
        final ThemeData accented = withPrismAccent(theme, 0xFF2D6079);
        expect(accented.bottomSheetTheme.modalBackgroundColor, accented.colorScheme.surface, reason: option.id);
      }
      for (final PrismThemeOption option in prismDarkThemes) {
        final ThemeData theme = option.theme;
        expect(theme.bottomSheetTheme.modalBackgroundColor, theme.colorScheme.surfaceContainerLow, reason: option.id);
      }
      for (final Brightness brightness in Brightness.values) {
        final ThemeData you = prismMaterialYouTheme(
          ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: brightness),
        );
        expect(you.bottomSheetTheme.modalBackgroundColor, you.colorScheme.surfaceContainerLow);
      }
    });

    test('an off switch track is 18 percent ink', () {
      final ColorScheme cs = kLightTheme.colorScheme;
      expect(kLightTheme.switchTheme.trackColor!.resolve(<WidgetState>{}), cs.onSurface.withValues(alpha: 0.18));
    });
  });

  group('PrismSegmented', () {
    Future<void> pumpSegmented(WidgetTester tester, ThemeData theme) => tester.pumpWidget(
      _host(
        PrismSegmented<int>(values: const <int>[0, 1], selected: 0, labelOf: (v) => 'Item $v', onChanged: (_) {}),
        theme: theme,
      ),
    );

    BoxDecoration thumb(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(
          find.descendant(of: find.byType(PrismSegmented<int>), matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.boxShadow != null);

    testWidgets('the thumb is a raised neutral surface, not ink, 44 high (48 on Android)', (tester) async {
      await pumpSegmented(tester, kLightTheme.copyWith(platform: TargetPlatform.iOS));
      expect(thumb(tester).color, kLightTheme.colorScheme.surface);
      expect(tester.getSize(find.byType(PrismSegmented<int>)).height, 44);

      await pumpSegmented(tester, kLightTheme.copyWith(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PrismSegmented<int>)).height, 48);

      await pumpSegmented(tester, kDarkTheme);
      await tester.pumpAndSettle();
      expect(thumb(tester).color, kDarkTheme.colorScheme.surfaceContainerHighest);
    });

    testWidgets('the selected label is ink w700, the others secondary w600', (tester) async {
      await pumpSegmented(tester, kLightTheme);
      await tester.pumpAndSettle();
      final ColorScheme cs = kLightTheme.colorScheme;
      TextStyle styleOf(String label) => tester
          .widget<DefaultTextStyle>(find.ancestor(of: find.text(label), matching: find.byType(DefaultTextStyle)).first)
          .style;
      expect(styleOf('Item 0').color, cs.onSurface);
      expect(styleOf('Item 0').fontWeight, FontWeight.w700);
      expect(styleOf('Item 1').color, cs.onSurfaceVariant);
      expect(styleOf('Item 1').fontWeight, FontWeight.w600);
    });
  });

  group('GlowText', () {
    test('a light stop is darkened until it reads on white, a dark stop is kept', () {
      const Color gold = Color(0xFFFFD86B);
      final Color readable = readableGlowStop(gold, Colors.black, Colors.white);
      expect(contrastRatio(readable, Colors.white), greaterThanOrEqualTo(4.5));
      expect(readableGlowStop(const Color(0xFF1A1A1A), Colors.black, Colors.white), const Color(0xFF1A1A1A));
    });
  });

  group('PrismThemePreview', () {
    testWidgets('draws the theme page, two decoded-small tiles and an accent pill', (tester) async {
      final ThemeData theme = kDarkTheme;
      await tester.pumpWidget(_host(SizedBox(width: 110, child: PrismThemePreview(theme: theme))));

      final List<Image> images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      for (final Image image in images) {
        expect(image.image, isA<ResizeImage>());
      }
      final Iterable<Color?> fills = tester
          .widgetList<ColoredBox>(
            find.descendant(of: find.byType(PrismThemePreview), matching: find.byType(ColoredBox)),
          )
          .map((box) => box.color);
      expect(fills, contains(theme.colorScheme.surface));
      final Iterable<Color?> pills = tester
          .widgetList<Container>(find.descendant(of: find.byType(PrismThemePreview), matching: find.byType(Container)))
          .map((c) => (c.decoration as BoxDecoration?)?.color);
      expect(pills, containsAll(<Color>[theme.colorScheme.onSurface, theme.colorScheme.primary]));
    });
  });

  group('PrismPage', () {
    testWidgets('a bottom bar has a hairline on top', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: kLightTheme,
          home: PrismPage(
            title: 'Title',
            body: const SizedBox(),
            bottomBar: PrismButton(label: 'Go', onPressed: () {}),
          ),
        ),
      );
      final Iterable<Border> borders = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>();
      expect(borders.any((b) => b.top.color == kLightTheme.colorScheme.onSurface.withValues(alpha: 0.08)), isTrue);
    });
  });
}
