import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

class ChallengeContextChip extends StatelessWidget {
  const ChallengeContextChip({required this.seed, required this.onRemove, super.key});
  final ChallengeSeed seed;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => InputChip(
    label: Text(context.l10n.challengeContext(seed.theme)),
    onDeleted: onRemove,
    deleteButtonTooltipMessage: context.l10n.challengeRemove,
  );
}
