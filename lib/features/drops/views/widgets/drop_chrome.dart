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

/// A small dark pill for the corner of a wall image: a lock and the price, "Owned" or "Missed".
class DropTileBadge extends StatelessWidget {
  const DropTileBadge({super.key, required this.icon, required this.label, this.coin = false});

  final IconData icon;
  final String label;

  /// Shows a coin after [label], for a price.
  final bool coin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: PrismTextStyles.caption(context).copyWith(
                color: Colors.white,
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
