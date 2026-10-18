import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:flutter/material.dart';

/// The painted chest. [lid] runs 0 (shut) to 1 (wide open), [glow] 0 to 1 is the light behind it.
class ChestArt extends StatelessWidget {
  const ChestArt({super.key, required this.size, this.lid = 0, this.glow = 0, this.locked = false});

  final double size;
  final double lid;
  final double glow;

  /// Draws the padlock on the front.
  final bool locked;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size);
}

/// The chest on the quest board for [stage]: locked, ready (it glows and wobbles), or opened.
class LiveChest extends StatelessWidget {
  const LiveChest({super.key, required this.stage, required this.size});

  final ChestStage stage;
  final double size;

  @override
  Widget build(BuildContext context) => ChestArt(size: size, locked: stage == ChestStage.locked);
}
