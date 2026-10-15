import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {Size? size, ThemeData? theme}) => MaterialApp(
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
