import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/quests/views/widgets/quest_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

QuestTileModel _daily({
  String? title,
  int progress = 1,
  int target = 3,
  bool done = false,
  QuestReward reward = const QuestReward(coins: 2, xp: 25),
}) => QuestTileModel(
  id: 'quest',
  info: QuestInfo(title: title ?? AppLocalizationsEn().economyQuestFav3, icon: Icons.favorite_border_rounded),
  scope: QuestScope.daily,
  progress: progress,
  target: target,
  done: done,
  reward: reward,
);

QuestTileModel _weekly({bool done = false}) => QuestTileModel(
  id: 'weekly',
  info: QuestInfo(title: AppLocalizationsEn().economyQuestWeeklySet5, icon: Icons.event_available_outlined),
  scope: QuestScope.weekly,
  progress: done ? 5 : 2,
  target: 5,
  done: done,
  reward: const QuestReward(coins: 30, xp: 150),
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
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,

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
      final AppLocalizationsEn l10n = AppLocalizationsEn();
      expect(
        find.bySemanticsLabel(
          l10n.economyQuestTileSemantics(
            l10n.economyQuestFav3,
            'false',
            1,
            3,
            2,
            25,
            'true',
            'true',
            'false',
            '',
            'false',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('reads done for a finished quest', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _daily(title: 'Set or save a wallpaper', target: 1, done: true));
      final AppLocalizationsEn l10n = AppLocalizationsEn();
      expect(
        find.bySemanticsLabel(
          l10n.economyQuestTileSemantics(
            l10n.economyQuestSetWall,
            'true',
            1,
            1,
            2,
            25,
            'true',
            'true',
            'false',
            '',
            'false',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('adds the week and the countdown for the weekly quest', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _weekly(), endsIn: '4d 2h');
      final AppLocalizationsEn l10n = AppLocalizationsEn();
      expect(
        find.bySemanticsLabel(
          l10n.economyQuestTileSemantics(
            l10n.economyQuestWeeklySet5,
            'false',
            2,
            5,
            30,
            150,
            'true',
            'true',
            'true',
            '4d 2h',
            'true',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('drops the countdown when the weekly reset time is unknown', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _weekly());
      final AppLocalizationsEn l10n = AppLocalizationsEn();
      expect(
        find.bySemanticsLabel(
          l10n.economyQuestTileSemantics(
            l10n.economyQuestWeeklySet5,
            'false',
            2,
            5,
            30,
            150,
            'true',
            'true',
            'true',
            '',
            'false',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('names only the rewards that pay', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _daily(reward: const QuestReward(coins: 1, xp: 0)));
      final AppLocalizationsEn l10n = AppLocalizationsEn();
      expect(
        find.bySemanticsLabel(
          l10n.economyQuestTileSemantics(
            l10n.economyQuestFav3,
            'false',
            1,
            3,
            1,
            0,
            'true',
            'false',
            'false',
            '',
            'false',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('content', () {
    testWidgets('shows the title once, the count and both rewards', (WidgetTester tester) async {
      await _pump(tester, _daily(reward: const QuestReward(coins: 7, xp: 40)));
      final AppLocalizationsEn l10n = AppLocalizationsEn();
      expect(find.text(l10n.economyQuestFav3), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text(l10n.economyCoinReward(7)), findsOneWidget);
      expect(find.text(l10n.economyXp(40)), findsOneWidget);
      expect(find.byType(PrismCoinIcon), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });

    testWidgets('puts the coin after the amount', (WidgetTester tester) async {
      await _pump(tester, _daily());
      final double amountEnd = tester.getTopRight(find.text(AppLocalizationsEn().economyCoinReward(2))).dx;
      expect(tester.getTopLeft(find.byType(PrismCoinIcon)).dx, greaterThan(amountEnd));
    });

    testWidgets('shows Done and a check when the quest is done', (WidgetTester tester) async {
      await _pump(tester, _daily(progress: 3, done: true));
      await tester.pumpAndSettle();
      expect(find.text(AppLocalizationsEn().actionDone), findsOneWidget);
      expect(find.text('3/3'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('hides a reward that pays nothing', (WidgetTester tester) async {
      await _pump(tester, _daily(reward: const QuestReward(coins: 0, xp: 25)));
      expect(find.byType(PrismCoinIcon), findsNothing);
      expect(find.text(AppLocalizationsEn().economyXp(25)), findsOneWidget);
    });

    testWidgets('shows the weekly tag with the countdown', (WidgetTester tester) async {
      await _pump(tester, _weekly(), endsIn: '4d 2h');
      expect(
        find.descendant(
          of: find.byType(PrismTag),
          matching: find.text(AppLocalizationsEn().economyWeeklyEndsIn('4d 2h')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the bare weekly tag without a countdown', (WidgetTester tester) async {
      await _pump(tester, _weekly());
      expect(
        find.descendant(of: find.byType(PrismTag), matching: find.text(AppLocalizationsEn().economyWeekly)),
        findsOneWidget,
      );
    });

    testWidgets('shows no tag on a daily quest', (WidgetTester tester) async {
      await _pump(tester, _daily(), endsIn: '4d 2h');
      expect(find.byType(PrismTag), findsNothing);
    });
  });

  group('progress bar', () {
    Size fill(WidgetTester tester) => tester.getSize(
      find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox)).first,
    );
    Size track(WidgetTester tester) =>
        tester.getSize(find.ancestor(of: find.byType(FractionallySizedBox), matching: find.byType(Container)).first);

    testWidgets('fills to the progress and is 6 points high', (WidgetTester tester) async {
      await _pump(tester, _daily(target: 4));
      await tester.pumpAndSettle();
      expect(fill(tester).height, 6);
      expect(fill(tester).width, moreOrLessEquals(track(tester).width / 4, epsilon: 0.01));
    });

    testWidgets('fills in the accent, and in the success colour when done', (WidgetTester tester) async {
      Color fillColor() {
        final DecoratedBox box = tester.widget<DecoratedBox>(
          find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox)).first,
        );
        return (box.decoration as BoxDecoration).color!;
      }

      await _pump(tester, _daily());
      expect(fillColor(), kLightTheme.colorScheme.primary);
      await _pump(tester, _daily(progress: 3, done: true));
      await tester.pumpAndSettle();
      expect(fillColor(), PrismColors.success);
    });
  });

  group('layout', () {
    testWidgets('the longest title fits a 320 px surface at 1.3x text', (WidgetTester tester) async {
      await _pump(
        tester,
        _daily(title: AppLocalizationsEn().economyQuestWotd, progress: 0, target: 1),
        width: 320,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(AppLocalizationsEn().economyQuestWotd), findsOneWidget);
    });

    testWidgets('the weekly tile fits a 320 px surface at 1.3x text', (WidgetTester tester) async {
      await _pump(tester, _weekly(), endsIn: '4d 2h', width: 320, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    for (final ThemeData theme in <ThemeData>[kLightTheme, kDarkTheme]) {
      testWidgets('a done weekly tile fits 390 px at text scale 2.4 (${theme.brightness.name})', (
        WidgetTester tester,
      ) async {
        await _pump(tester, _weekly(done: true), endsIn: '4d 2h', theme: theme, textScale: 2.4);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(AppLocalizationsEn().actionDone), findsOneWidget);
        expect(find.text(AppLocalizationsEn().economyWeeklyEndsIn('4d 2h')), findsOneWidget);
      });
    }

    testWidgets('text beyond 1.5x does not grow the tile', (WidgetTester tester) async {
      await _pump(tester, _daily(), textScale: 1.5);
      final Size capped = tester.getSize(find.byType(QuestTile));
      await _pump(tester, _daily(), textScale: 2.4);
      expect(tester.getSize(find.byType(QuestTile)), capped);
    });

    testWidgets('the reward column lines up at the row end', (WidgetTester tester) async {
      await _pump(tester, _daily(reward: const QuestReward(coins: 2, xp: 125)));
      final double rowEnd = tester.getTopRight(find.byType(QuestTile)).dx;
      final double xpEnd = tester.getTopRight(find.text(AppLocalizationsEn().economyXp(125))).dx;
      final double coinEnd = tester.getTopRight(find.byType(PrismCoinIcon)).dx;
      expect(xpEnd, moreOrLessEquals(coinEnd, epsilon: 0.01));
      expect(rowEnd - xpEnd, moreOrLessEquals(16, epsilon: 0.01));
    });

    testWidgets('the dark theme pumps', (WidgetTester tester) async {
      await _pump(tester, _daily(), theme: kDarkTheme);
      expect(tester.takeException(), isNull);
      expect(find.text('1/3'), findsOneWidget);
    });
  });
}
