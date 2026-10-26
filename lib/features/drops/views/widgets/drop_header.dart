import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_chrome.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The top of a Drop page: the name, the dates and wall count, the time left, and a button for every wall left.
class DropHeader extends StatelessWidget {
  const DropHeader({
    super.key,
    required this.drop,
    required this.now,
    required this.remaining,
    required this.live,
    this.busy = false,
    this.onUnlockAll,
    this.onRename,
  });

  final DropEntity drop;
  final DateTime now;
  final int remaining;
  final bool live;

  /// The pack is being unlocked.
  final bool busy;
  final VoidCallback? onUnlockAll;

  /// Admins only.
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isPro = app_state.prismUser.premium;
    final String walls = l10n.economyDropWallCount(drop.count);
    final String stats = drop.collectors > 0 ? l10n.economyDropStats(walls, drop.collectors) : walls;
    final int owned = drop.count - remaining;
    final int saving = packSaving(drop, remaining: remaining, isPro: isPro);
    final VoidCallback? rename = onRename;
    final VoidCallback? unlockAll = onUnlockAll;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(drop.displayTitle(l10n), style: PrismTextStyles.screenTitle(context)),
                ),
              ),
              if (rename != null)
                IconButton(tooltip: l10n.economyDropRename, icon: const Icon(Icons.edit_outlined), onPressed: rename),
            ],
          ),
          const SizedBox(height: PrismSpace.xxs),
          Text('${drop.datesLabel(l10n)} · $stats', style: PrismTextStyles.caption(context)),
          const SizedBox(height: PrismSpace.sm),
          Wrap(
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              if (live) DropTimeTag(drop: drop, now: now) else PrismTag(label: l10n.economyDropEndedHeadline),
              if (owned > 0)
                PrismTag(
                  label: l10n.economyDropCollected(owned, drop.count),
                  tone: PrismTone.success,
                  icon: Icons.check_rounded,
                ),
              if (live && remaining > 0 && isPro) PrismTag(label: l10n.economyProPrice, tone: PrismTone.accent),
            ],
          ),
          if (live && remaining > 1 && unlockAll != null) ...<Widget>[
            const SizedBox(height: PrismSpace.md),
            PrismButton(
              label: l10n.economyDropUnlockAll(remaining, drop.packPrice(remaining: remaining, isPro: isPro)),
              expand: true,
              variant: PrismButtonVariant.tonal,
              trailing: const PrismCoinIcon(size: 18),
              loading: busy,
              onPressed: busy ? null : unlockAll,
            ),
            if (saving > 0)
              Padding(
                padding: const EdgeInsets.only(top: PrismSpace.xs),
                child: Center(child: Text(l10n.economyDropSave(saving), style: PrismTextStyles.caption(context))),
              ),
          ],
        ],
      ),
    );
  }
}
