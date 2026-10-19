import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The foot of the preview. Locked and live: price, buy button and countdown. Owned: an Open button. Ended and locked:
/// one line of text and no button.
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
    final DropPhase phase = drop.phaseAt(now);
    final bool ended = phase == DropPhase.ended;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (owned)
            _GoldButton(label: context.l10n.economyOpen, onTap: onOpen)
          else if (ended)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.md),
              child: Text(
                context.l10n.economyDropEndedHeadline,
                style: TextStyle(color: DropPalette.inkMuted, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            )
          else
            _GoldButton(
              label: context.l10n.economyDropUnlockFor(drop.wallPrice(isPro: isPro)),
              trailing: const PrismCoinIcon(),
              loading: busy,
              onTap: onUnlock,
            ),
          if (!owned && !ended) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _Countdown(label: drop.endsInLabel(context.l10n, now), urgent: phase == DropPhase.lastCall),
                if (isPro) ...<Widget>[const SizedBox(width: PrismSpace.sm), _ProTag()],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.label, required this.urgent});

  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final Color color = urgent ? DropPalette.urgent : DropPalette.inkMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (urgent) ...<Widget>[
          Text(
            context.l10n.economyDropLastCallLabel,
            style: TextStyle(color: DropPalette.urgent, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4),
          ),
          const SizedBox(width: 6),
          DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: const SizedBox.square(dimension: 3),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ProTag extends StatelessWidget {
  const _ProTag();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        border: Border.all(color: DropPalette.gold.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          context.l10n.economyProPrice,
          style: TextStyle(color: DropPalette.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
        ),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap, this.trailing, this.loading = false});

  final String label;
  final Widget? trailing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !loading,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: loading ? null : onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PrismRadius.pill),
            gradient: DropPalette.foil,
            boxShadow: <BoxShadow>[
              BoxShadow(color: DropPalette.gold.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 6)),
            ],
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: Center(
              child: loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: DropPalette.obsidian),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          label,
                          style: const TextStyle(
                            color: DropPalette.obsidian,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (trailing != null) ...<Widget>[const SizedBox(width: PrismSpace.xs), trailing!],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
