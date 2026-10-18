import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/quests/views/widgets/quest_tile.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

QuestTileModel _daily({
  String title = 'Favourite 3 walls',
  int progress = 1,
  int target = 3,
  bool done = false,
  QuestReward reward = const QuestReward(coins: 2, xp: 25),
}) => QuestTileModel(
  id: 'quest',
  info: QuestInfo(title: title, icon: Icons.favorite_border_rounded),
  scope: QuestScope.daily,
  progress: progress,
  target: target,
  done: done,
  reward: reward,
);

QuestTileModel _weekly() => const QuestTileModel(
  id: 'weekly',
  info: QuestInfo(title: 'Save or set 5 walls', icon: Icons.event_available_outlined),
  scope: QuestScope.weekly,
  progress: 2,
  target: 5,
  done: false,
  reward: QuestReward(coins: 30, xp: 150),
);

Future<void> _pump(
  WidgetTester tester,
  QuestTileModel quest, {
  String? endsIn,
  ThemeData? theme,
  double width = 390,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? kLightTheme,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: QuestTile(quest: quest, endsIn: endsIn),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('semantics', () {
    testWidgets('reads the count for a quest in progress', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _daily());
      expect(find.bySemanticsLabel('Favourite 3 walls, 1 of 3. Pays 2 coins and 25 XP'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reads done for a finished quest', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _daily(title: 'Set or save a wallpaper', target: 1, done: true));
      expect(find.bySemanticsLabel('Set or save a wallpaper, done. Pays 2 coins and 25 XP'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('adds the week and the countdown for the weekly quest', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _weekly(), endsIn: '4d 2h');
      expect(
        find.bySemanticsLabel('Save or set 5 walls, 2 of 5. Pays 30 coins and 150 XP. This week, ends in 4d 2h'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('drops the countdown when the weekly reset time is unknown', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _weekly());
      expect(find.bySemanticsLabel('Save or set 5 walls, 2 of 5. Pays 30 coins and 150 XP. This week'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('names only the rewards that pay', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _daily(reward: const QuestReward(coins: 1, xp: 0)));
      expect(find.bySemanticsLabel('Favourite 3 walls, 1 of 3. Pays 1 coin'), findsOneWidget);
      handle.dispose();
    });
  });

  group('content', () {
    testWidgets('shows the title in capitals, the count and both rewards', (WidgetTester tester) async {
      await _pump(tester, _daily(reward: const QuestReward(coins: 7, xp: 40)));
      expect(find.text('FAVOURITE 3 WALLS'), findsNWidgets(2));
      expect(find.text('1/3'), findsNWidgets(2));
      expect(find.text('7'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.byType(PrismCoinIcon), findsOneWidget);
    });

    testWidgets('shows DONE instead of the count when the quest is done', (WidgetTester tester) async {
      await _pump(tester, _daily(progress: 3, done: true));
      expect(find.text('DONE'), findsNWidgets(2));
      expect(find.text('3/3'), findsNothing);
    });

    testWidgets('hides the chip of a reward that pays nothing', (WidgetTester tester) async {
      await _pump(tester, _daily(reward: const QuestReward(coins: 0, xp: 25)));
      expect(find.byType(PrismCoinIcon), findsNothing);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('shows the weekly ribbon with the countdown', (WidgetTester tester) async {
      await _pump(tester, _weekly(), endsIn: '4d 2h');
      expect(find.text('WEEKLY · 4d 2h'), findsNWidgets(2));
    });

    testWidgets('shows the bare weekly ribbon without a countdown', (WidgetTester tester) async {
      await _pump(tester, _weekly());
      expect(find.text('WEEKLY'), findsNWidgets(2));
    });

    testWidgets('shows no ribbon on a daily quest', (WidgetTester tester) async {
      await _pump(tester, _daily(), endsIn: '4d 2h');
      expect(find.textContaining('WEEKLY'), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('the longest title fits a 320 px surface at 1.3x text', (WidgetTester tester) async {
      await _pump(
        tester,
        _daily(title: "Open today's Wall of the Day", progress: 0, target: 1),
        width: 320,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text("OPEN TODAY'S WALL OF THE DAY"), findsNWidgets(2));
    });

    testWidgets('the weekly tile fits a 320 px surface at 1.3x text', (WidgetTester tester) async {
      await _pump(tester, _weekly(), endsIn: '4d 2h', width: 320, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the dark theme pumps', (WidgetTester tester) async {
      await _pump(tester, _daily(), theme: kDarkTheme);
      expect(tester.takeException(), isNull);
      expect(find.text('1/3'), findsNWidgets(2));
    });
  });
}
