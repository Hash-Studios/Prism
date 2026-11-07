import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

const List<FontFeature> _tabular = <FontFeature>[FontFeature.tabularFigures()];

/// One quest as a flat row for a [PrismGroup]: icon tile, title, progress bar and the reward.
/// [endsIn] is the weekly countdown, such as "4d 2h".
class QuestTile extends StatelessWidget {
  const QuestTile({super.key, required this.quest, this.endsIn});

  final QuestTileModel quest;
  final String? endsIn;

  bool get _weekly => quest.scope == QuestScope.weekly;

  String _semanticsLabel(AppLocalizations l10n) => l10n.economyQuestTileSemantics(
    quest.info.title,
    quest.done.toString(),
    quest.progress,
    quest.target,
    quest.reward.coins,
    quest.reward.xp,
    (quest.reward.coins > 0).toString(),
    (quest.reward.xp > 0).toString(),
    _weekly.toString(),
    endsIn ?? '',
    (endsIn != null).toString(),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Widget title = Text(
      quest.info.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: PrismTextStyles.rowTitle(context),
    );
    return Semantics(
      container: true,
      label: _semanticsLabel(l10n),
      excludeSemantics: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.sm),
          child: Row(
            children: <Widget>[
              _Leading(icon: quest.info.icon, done: quest.done),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_weekly)
                      Wrap(
                        spacing: PrismSpace.xs,
                        runSpacing: PrismSpace.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          title,
                          PrismTag(label: endsIn == null ? l10n.economyWeekly : l10n.economyWeeklyEndsIn(endsIn!)),
                        ],
                      )
                    else
                      title,
                    const SizedBox(height: PrismSpace.xs),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ProgressBar(fraction: quest.fraction, done: quest.done),
                        ),
                        const SizedBox(width: PrismSpace.xs),
                        // Min widths keep the bars the same length down the group for short counts and rewards.
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 36),
                          child: Text(
                            quest.done
                                ? l10n.actionDone
                                : '${formatLocalizedNumber(quest.progress, l10n)}/${formatLocalizedNumber(quest.target, l10n)}',
                            maxLines: 1,
                            textAlign: TextAlign.start,
                            style: PrismTextStyles.caption(context).copyWith(fontFeatures: _tabular),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (quest.reward.coins > 0 || quest.reward.xp > 0) ...<Widget>[
                const SizedBox(width: PrismSpace.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 52),
                  child: _Reward(reward: quest.reward),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.icon, required this.done});

  final IconData icon;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: context.motion(PrismDurations.fast),
      curve: PrismCurves.enter,
      // Same size and radius as the PrismRow icon tile, so the title sits on the PrismGroup divider inset (60).
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: done ? PrismColors.success : cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PrismRadius.xs + 2),
      ),
      child: AnimatedSwitcher(
        duration: context.motion(PrismDurations.fast),
        switchInCurve: PrismCurves.enter,
        switchOutCurve: PrismCurves.exitReverse,
        child: Icon(
          done ? Icons.check_rounded : icon,
          key: ValueKey<bool>(done),
          size: 18,
          color: done ? Colors.white : cs.onSurface,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.done});

  final double fraction;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius pill = BorderRadius.circular(PrismRadius.pill);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: fraction),
      duration: context.motion(PrismDurations.base),
      curve: PrismCurves.enter,
      builder: (BuildContext context, double value, _) => Container(
        height: 6,
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.08), borderRadius: pill),
        child: FractionallySizedBox(
          widthFactor: value,
          child: DecoratedBox(
            decoration: BoxDecoration(color: done ? PrismColors.success : cs.primary, borderRadius: pill),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// "+2" and a coin, with "25 XP" under it. Right-aligned so the amounts line up down the group.
class _Reward extends StatelessWidget {
  const _Reward({required this.reward});

  final QuestReward reward;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (reward.coins > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.economyCoinReward(reward.coins),
                style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w700, fontFeatures: _tabular),
              ),
              const SizedBox(width: PrismSpace.xxs),
              const PrismCoinIcon(size: 14),
            ],
          ),
        if (reward.xp > 0)
          Text(
            l10n.economyXp(reward.xp),
            style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.w600, fontFeatures: _tabular),
          ),
      ],
    );
  }
}
