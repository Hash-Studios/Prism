import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {Size? size, ThemeData? theme}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,

    theme: theme,
    home: Scaffold(
      body: size == null
          ? child
          : Center(
              child: SizedBox(width: size.width, height: size.height, child: child),
            ),
    ),
  );

  const moods = {
    GlintStateKind.empty: GlintMood.calm,
    GlintStateKind.nothingNew: GlintMood.sleepy,
    GlintStateKind.error: GlintMood.sad,
    GlintStateKind.offline: GlintMood.worried,
    GlintStateKind.loading: GlintMood.curious,
  };

  for (final entry in moods.entries) {
    testWidgets('${entry.key} shows ${entry.value}', (tester) async {
      await tester.pumpWidget(host(GlintState(kind: entry.key, title: 'T', body: 'B')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<Glint>(find.byType(Glint)).mood, entry.value);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  }

  testWidgets('action button fires onAction', (tester) async {
    int calls = 0;
    await tester.pumpWidget(
      host(GlintState(kind: GlintStateKind.error, title: 'T', actionLabel: 'Retry', onAction: () => calls++)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Retry'));
    expect(calls, 1);
  });

  testWidgets('the action is primary by default and tonal on request', (tester) async {
    await tester.pumpWidget(
      host(GlintState(kind: GlintStateKind.empty, title: 'T', actionLabel: 'Go', onAction: () {})),
    );
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).variant, PrismButtonVariant.primary);

    await tester.pumpWidget(
      host(
        GlintState(
          kind: GlintStateKind.empty,
          title: 'T',
          actionLabel: 'Go',
          onAction: () {},
          actionVariant: PrismButtonVariant.tonal,
        ),
      ),
    );
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).variant, PrismButtonVariant.tonal);
  });

  testWidgets('sits above the centre on a tall area and in the centre on a short one', (tester) async {
    await tester.pumpWidget(
      host(
        const GlintState(kind: GlintStateKind.empty, title: 'T'),
        size: const Size(360, 600),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final Rect tall = tester.getRect(find.byType(GlintState));
    final double tallMiddle = (tester.getTopLeft(find.byType(Glint)).dy + tester.getBottomLeft(find.text('T')).dy) / 2;
    expect(tallMiddle, lessThan(tall.center.dy - 60), reason: 'biased towards the top');

    await tester.pumpWidget(
      host(
        const GlintState(kind: GlintStateKind.empty, title: 'T'),
        size: const Size(360, 400),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final Rect short = tester.getRect(find.byType(GlintState));
    final double shortMiddle = (tester.getTopLeft(find.byType(Glint)).dy + tester.getBottomLeft(find.text('T')).dy) / 2;
    expect(shortMiddle, closeTo(short.center.dy, 1));
  });

  testWidgets('does not overflow at 320x200', (tester) async {
    await tester.pumpWidget(
      host(
        GlintState(
          kind: GlintStateKind.offline,
          title: 'Offline',
          body: 'Check your link',
          actionLabel: 'Retry',
          onAction: () {},
        ),
        size: const Size(320, 200),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 2x text a state taller than its area scrolls instead of overflowing', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: host(
          GlintState(
            kind: GlintStateKind.error,
            title: 'Could not load your folders',
            body: 'Check your connection and try again. Your folders are safe and will come back.',
            actionLabel: 'Try again',
            onAction: () {},
          ),
          size: const Size(320, 300),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing, reason: 'not tight, so no scale-down');
    final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.scrollUntilVisible(find.text('Try again'), 50, scrollable: find.byType(Scrollable));
    expect(find.text('Try again').hitTestable(), findsOneWidget);
  });

  testWidgets('title and body remain visible in light and dark themes', (tester) async {
    for (final ThemeData theme in <ThemeData>[kLightTheme3, kDarkTheme8]) {
      await tester.pumpWidget(
        host(
          const GlintState(kind: GlintStateKind.offline, title: 'Offline', body: 'Check your connection'),
          theme: theme,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Color titleColor = tester.renderObject<RenderParagraph>(find.text('Offline')).text.style!.color!;
      final Color bodyColor = tester
          .renderObject<RenderParagraph>(find.text('Check your connection'))
          .text
          .style!
          .color!;
      expect(_contrastRatio(titleColor, theme.colorScheme.surface), greaterThanOrEqualTo(3));
      expect(_contrastRatio(bodyColor, theme.colorScheme.surface), greaterThanOrEqualTo(3));
    }
  });

  testWidgets('error and offline states are live regions, the other kinds are not', (tester) async {
    final handle = tester.ensureSemantics();
    for (final entry in <GlintStateKind, bool>{
      GlintStateKind.error: true,
      GlintStateKind.offline: true,
      GlintStateKind.empty: false,
      GlintStateKind.nothingNew: false,
      GlintStateKind.loading: false,
    }.entries) {
      await tester.pumpWidget(host(GlintState(kind: entry.key, title: 'Title')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Title')),
        isSemantics(isLiveRegion: entry.value),
        reason: '${entry.key}',
      );
    }
    handle.dispose();
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
