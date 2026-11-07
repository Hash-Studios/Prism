import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Coins saved by the pack against buying each wall left one by one. Zero when the pack is not cheaper.
int packSaving(DropEntity drop, {required int remaining, required bool isPro}) {
  if (remaining <= 1) return 0;
  final int saving = remaining * drop.wallPrice(isPro: isPro) - drop.packPrice(remaining: remaining, isPro: isPro);
  return saving > 0 ? saving : 0;
}

/// "Ends in 6d 15h" as a tag. It turns to the warning tone in the last day.
class DropTimeTag extends StatelessWidget {
  const DropTimeTag({super.key, required this.drop, required this.now});

  final DropEntity drop;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final bool lastCall = drop.phaseAt(now) == DropPhase.lastCall;
    return PrismTag(
      label: drop.endsInLabel(context.l10n, now),
      tone: lastCall ? PrismTone.warning : PrismTone.neutral,
      icon: Icons.schedule_rounded,
    );
  }
}

/// A small light pill for the corner of a wall image: a lock and the price, "Owned" or "Missed".
class DropTileBadge extends StatelessWidget {
  const DropTileBadge({super.key, required this.icon, required this.label, this.coin = false});

  final IconData icon;
  final String label;

  /// Shows a coin after [label], for a price.
  final bool coin;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    // A light pill reads on dark and light walls alike; a dark one vanished on dark walls.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 1))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: PrismSpace.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: cs.onSurface),
            const SizedBox(width: PrismSpace.xxs),
            Text(
              label,
              style: PrismTextStyles.caption(context).copyWith(
                color: cs.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            if (coin) ...<Widget>[const SizedBox(width: 3), const PrismCoinIcon(size: 12)],
          ],
        ),
      ),
    );
  }
}
