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

    test('an off switch track is the highest container with an outline', () {
      final ColorScheme cs = kLightTheme.colorScheme;
      expect(kLightTheme.switchTheme.trackColor!.resolve(<WidgetState>{}), cs.surfaceContainerHighest);
      expect(kLightTheme.switchTheme.trackOutlineColor!.resolve(<WidgetState>{}), cs.outline);
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
    test('a light stop is darkened until it reads 6:1 on white, a dark stop is kept', () {
      const Color gold = Color(0xFFFFD86B);
      final Color readable = readableGlowStop(gold, Colors.black, Colors.white);
      expect(contrastRatio(readable, Colors.white), greaterThanOrEqualTo(6.0));
      expect(readableGlowStop(const Color(0xFF1A1A1A), Colors.black, Colors.white), const Color(0xFF1A1A1A));
    });
  });

  group('PrismIconButton glass', () {
    testWidgets('a page-colour circle with an ink icon and a soft shadow', (tester) async {
      await tester.pumpWidget(
        _host(PrismIconButton(icon: Icons.share_rounded, tooltip: 'Share', glass: true, onPressed: () {})),
      );
      final ColorScheme cs = kLightTheme.colorScheme;
      final IconButton button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.color, cs.onSurface);
      expect(button.style!.backgroundColor!.resolve(<WidgetState>{}), cs.surface.withValues(alpha: 0.92));
      final Finder shadowBox = find.descendant(
        of: find.byType(PrismIconButton),
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && (w.decoration as BoxDecoration?)?.boxShadow != null,
        ),
      );
      final BoxDecoration shadow = tester.widget<DecoratedBox>(shadowBox).decoration as BoxDecoration;
      expect(shadow.shape, BoxShape.circle);
      expect(shadow.boxShadow!.single.color, const Color(0x1F000000));
      expect(tester.getSize(shadowBox), const Size.square(44), reason: 'the shadow matches the circle, not the target');
    });
  });

  group('PrismTextField', () {
    testWidgets('the label lines up with the text inside the field, the hint is secondary text', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 300,
            child: PrismTextField(label: 'Name', hint: 'Ana'),
          ),
        ),
      );
      final double fieldLeft = tester.getTopLeft(find.byType(TextField)).dx;
      expect(tester.getTopLeft(find.text('Name')).dx - fieldLeft, PrismSpace.md);
      expect(kLightTheme.inputDecorationTheme.hintStyle!.color, kLightTheme.colorScheme.onSurfaceVariant);
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
    bool hasHairline(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<Border>()
        .any((b) => b.top.color == kLightTheme.colorScheme.onSurface.withValues(alpha: 0.08));

    Future<bool> pumpBar(WidgetTester tester, Widget body) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: kLightTheme,
          home: PrismPage(
            title: 'Title',
            body: body,
            bottomBar: PrismButton(label: 'Go', onPressed: () {}),
          ),
        ),
      );
      await tester.pump();
      return hasHairline(tester);
    }

    testWidgets('a bottom bar has a hairline on top only while content scrolls under it', (tester) async {
      expect(await pumpBar(tester, const PrismCenteredScroll(child: Text('Short'))), isFalse);
      expect(await pumpBar(tester, ListView(children: <Widget>[for (int i = 0; i < 40; i++) Text('Row $i')])), isTrue);
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(hasHairline(tester), isFalse, reason: 'at the end of the list nothing is under the bar');
    });

    testWidgets('PrismCenteredScroll lifts short content a little above the middle and scrolls long content', (
      tester,
    ) async {
      await pumpBar(tester, const PrismCenteredScroll(child: SizedBox(width: 100, height: 100, key: Key('box'))));
      final Rect area = tester.getRect(find.byType(PrismCenteredScroll));
      final double middle = tester.getCenter(find.byKey(const Key('box'))).dy;
      expect(middle, lessThan(area.center.dy));
      expect(middle, greaterThan(area.center.dy - 60));

      await pumpBar(tester, const PrismCenteredScroll(child: SizedBox(width: 100, height: 3000)));
      expect(tester.takeException(), isNull);
      final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable).last);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
    });
  });
}
