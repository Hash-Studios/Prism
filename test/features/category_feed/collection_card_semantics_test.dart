import 'package:Prism/features/category_feed/views/widgets/collection_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collection card semantic tap invokes its callback', (tester) async {
    var taps = 0;
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CollectionCard(
              data: const CollectionCardData(
                kind: CollectionCardKind.collection,
                name: 'Minimal',
                thumbUrl: '',
                isPremium: false,
              ),
              onTap: () => taps++,
            ),
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Collection, Minimal'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
      );
      await tester.pump();

      expect(taps, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the name is a w600 white label with a soft shadow over a dark lower scrim', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionCard(
            data: const CollectionCardData(
              kind: CollectionCardKind.collection,
              name: 'Minimal',
              thumbUrl: '',
              isPremium: false,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    final TextStyle style = tester.widget<Text>(find.text('Minimal')).style!;
    expect(style.color, Colors.white);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.shadows, isNotEmpty);
    final LinearGradient scrim = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => (box.decoration as BoxDecoration).gradient)
        .whereType<LinearGradient>()
        .single;
    expect(scrim.begin, Alignment.center);
    expect(scrim.colors.last, Colors.black.withValues(alpha: 0.65));
  });
}
