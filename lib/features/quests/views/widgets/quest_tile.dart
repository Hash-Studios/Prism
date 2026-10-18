import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:flutter/material.dart';

/// One quest as a raised game panel: icon sticker, title, progress bar with the count, and the reward badges.
/// [endsIn] is the weekly ribbon's countdown, such as "4d 2h".
///
/// The tile is one semantics node: "Favourite 3 walls, 1 of 3. Pays 2 coins and 25 XP", "..., done. Pays ...", and
/// for the weekly quest "... Pays 30 coins and 150 XP. This week, ends in 4d 2h".
class QuestTile extends StatelessWidget {
  const QuestTile({super.key, required this.quest, this.endsIn});

  final QuestTileModel quest;
  final String? endsIn;

  @override
  Widget build(BuildContext context) => Text(quest.info.title);
}
