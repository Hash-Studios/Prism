import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_chrome.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The foot of the preview. Locked and live: the buy button and the time left. Owned: an Open button. Ended and
/// locked: one line of text and no button.
class PreviewBottomBar extends StatelessWidget {
  const PreviewBottomBar({
    super.key,
    required this.drop,
    required this.now,
    required this.owned,
    required this.busy,
    required this.isPro,
    required this.onUnlock,
    required this.onOpen,
  });

  final DropEntity drop;
  final DateTime now;
  final bool owned;
  final bool busy;
  final bool isPro;
  final VoidCallback onUnlock;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bool ended = drop.phaseAt(now) == DropPhase.ended;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (owned)
            PrismButton(label: context.l10n.economyOpen, expand: true, onPressed: onOpen)
          else if (ended)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.md),
              child: Text(context.l10n.economyDropEndedHeadline, style: PrismTextStyles.rowTitle(context)),
            )
          else
            PrismButton(
              label: context.l10n.economyDropUnlockFor(drop.wallPrice(isPro: isPro)),
              expand: true,
              trailing: const PrismCoinIcon(size: 18),
              loading: busy,
              onPressed: busy ? null : onUnlock,
            ),
          if (!owned && !ended) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: PrismSpace.xs,
              runSpacing: PrismSpace.xs,
              children: <Widget>[
                DropTimeTag(drop: drop, now: now),
                if (isPro) PrismTag(label: context.l10n.economyProPrice, tone: PrismTone.accent),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
