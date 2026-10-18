import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/views/widgets/chest_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpChest(WidgetTester tester, ChestStage stage, {bool reduceMotion = false}) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Center(child: LiveChest(stage: stage, size: 120)),
    ),
  );

  testWidgets('a ready chest keeps animating, and stops once it is opened', (tester) async {
    await pumpChest(tester, ChestStage.ready);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await pumpChest(tester, ChestStage.opened);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a ready chest under reduced motion runs no animation', (tester) async {
    await pumpChest(tester, ChestStage.ready, reduceMotion: true);
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a locked chest stays still', (tester) async {
    await pumpChest(tester, ChestStage.locked);
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
