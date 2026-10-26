import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The home carousel page for a live Drop: its cover wall in full, the Drop name, the wall count and the time left.
class DropCarouselSlide extends StatelessWidget {
  const DropCarouselSlide({super.key, required this.drop, required this.now, required this.onTap, this.memCacheHeight});

  final DropEntity drop;
  final DateTime now;
  final VoidCallback onTap;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l10n = context.l10n;
    final bool lastCall = drop.phaseAt(now) == DropPhase.lastCall;
    final String cover = drop.walls.isEmpty ? '' : drop.walls.first.thumb;
    final String title = drop.displayTitle(l10n);
    final String detail = l10n.economyDropCarouselDetail(drop.count, drop.endsInLabel(l10n, now));
    return FeedHeroCard(
      image: cover.isEmpty
          ? ColoredBox(color: cs.surfaceContainerHigh)
          : PrismImageTile(url: cover, memCacheHeight: memCacheHeight),
      semanticLabel: l10n.economyDropCarouselSemantics(title, detail, lastCall.toString()),
      title: title,
      subtitle: detail,
      tag: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        child: ColoredBox(
          color: cs.surfaceContainerHigh,
          child: PrismTag(
            label: lastCall ? l10n.economyDropLastCallLabel : l10n.economyWeeklyDrop,
            tone: lastCall ? PrismTone.warning : PrismTone.neutral,
            icon: Icons.lock_rounded,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
