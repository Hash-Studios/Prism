@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/quests/views/widgets/quest_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'qa_harness.dart';

QuestTileModel _quest(
  String title,
  IconData icon, {
  required int progress,
  required int target,
  bool done = false,
  QuestScope scope = QuestScope.daily,
  QuestReward reward = const QuestReward(coins: 2, xp: 25),
}) => QuestTileModel(
  id: title,
  info: QuestInfo(title: title, icon: icon),
  scope: scope,
  progress: progress,
  target: target,
  done: done,
  reward: reward,
);

Widget _column() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 14,
  children: <Widget>[
    QuestTile(quest: _quest('Download 2 walls', Icons.download_rounded, progress: 0, target: 2)),
    QuestTile(quest: _quest('Favourite 3 walls', Icons.favorite_border_rounded, progress: 1, target: 3)),
    QuestTile(quest: _quest('Set or save a wallpaper', Icons.wallpaper_rounded, progress: 1, target: 1, done: true)),
    QuestTile(quest: _quest("Open today's Wall of the Day", Icons.today_outlined, progress: 0, target: 1)),
    QuestTile(
      quest: _quest(
        'Save or set 5 walls',
        Icons.event_available_outlined,
        progress: 2,
        target: 5,
        scope: QuestScope.weekly,
        reward: const QuestReward(coins: 30, xp: 150),
      ),
      endsIn: '4d 2h',
    ),
  ],
);

Widget _screen(Widget child) => Scaffold(
  body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), child: child),
);

Widget _withAccent(ThemeData theme, Color accent, Widget child) => Theme(
  data: theme.copyWith(colorScheme: theme.colorScheme.copyWith(primary: accent)),
  child: child,
);

void main() {
  setUpAll(() async {
    registerFallbackValue(WallpaperDetailRoute());
    if (qaRender) await loadFonts();
  });

  qaScreen('quest_tiles', height: 900, (QaShot shot) async {
    await shot.pump(_screen(_column()));
    await shot.save('quest_tiles');
  });

  qaScreen('quest_tiles_accents', height: 1100, (QaShot shot) async {
    await shot.pump(
      _screen(
        Column(
          spacing: 24,
          children: <Widget>[
            _withAccent(shot.theme, const Color(0xFF3D7BFF), _column()),
            _withAccent(shot.theme, const Color(0xFFFFFFFF), _column()),
          ],
        ),
      ),
    );
    await shot.save('quest_tiles_accents');
  });
}
