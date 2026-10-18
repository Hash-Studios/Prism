import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/views/widgets/chest_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpChest(
    WidgetTester tester,
    ChestStage stage, {
    bool reduceMotion = false,
    bool tickersEnabled = true,
  }) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Center(
        child: TickerMode(
          enabled: tickersEnabled,
          child: LiveChest(stage: stage, size: 120),
        ),
      ),
    ),
  );

  void expectChestDrawn(WidgetTester tester) {
    expect(tester.getSize(find.byType(LiveChest)), const Size.square(120));
    expect(find.descendant(of: find.byType(LiveChest), matching: find.byType(CustomPaint)), findsOneWidget);
  }

  testWidgets('a ready chest keeps animating, and stops once it is opened', (tester) async {
    await pumpChest(tester, ChestStage.ready);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    expectChestDrawn(tester);

    await pumpChest(tester, ChestStage.opened);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expectChestDrawn(tester);
  });

  testWidgets('a ready chest on a hidden tab draws no frames, and draws again when the tab shows', (tester) async {
    await pumpChest(tester, ChestStage.ready, tickersEnabled: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expectChestDrawn(tester);

    await pumpChest(tester, ChestStage.ready);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('a ready chest under reduced motion runs no animation', (tester) async {
    await pumpChest(tester, ChestStage.ready, reduceMotion: true);
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
    expectChestDrawn(tester);
  });

  testWidgets('a locked chest stays still', (tester) async {
    await pumpChest(tester, ChestStage.locked);
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
    expectChestDrawn(tester);
  });
}
