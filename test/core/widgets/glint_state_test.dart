import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {Size? size}) => MaterialApp(
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
}
