import 'package:Prism/features/category_feed/views/widgets/collection_card.dart';
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
}
