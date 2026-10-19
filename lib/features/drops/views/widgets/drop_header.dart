import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/painters/ticket_painter.dart';
import 'package:Prism/features/drops/views/widgets/drop_chrome.dart';
import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The obsidian hero of a Drop: title, countdown and a ticket with what a wall and the pack cost right now.
class DropHeader extends StatelessWidget {
  const DropHeader({super.key, required this.drop, required this.now, required this.remaining, required this.live});

  final DropEntity drop;
  final DateTime now;
  final int remaining;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isPro = app_state.prismUser.premium;
    final String walls = l10n.economyDropWallCount(drop.count);
    final String stats = drop.collectors > 0 ? l10n.economyDropStats(walls, drop.collectors) : walls;
    final int owned = drop.count - remaining;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.md),
      child: DropSurface(
        radius: PrismRadius.lg + 4,
        child: Padding(
          padding: const EdgeInsets.all(PrismSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.economyDropHeader(dropWeekLabel(drop.weekKey)), style: dropCapsStyle()),
              const SizedBox(height: PrismSpace.sm),
              Text(
                drop.displayTitle(context.l10n),
                style: const TextStyle(
                  fontFamily: PrismFonts.fraunces,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: -0.4,
                  color: DropPalette.ink,
                ),
              ),
              const SizedBox(height: PrismSpace.xs),
              Text(
                stats,
                style: const TextStyle(
                  fontFamily: PrismFonts.proximaNova,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: DropPalette.inkMuted,
                ),
              ),
              const SizedBox(height: PrismSpace.lg),
              if (live)
                DropCountdown(drop: drop, now: now)
              else
                Text(l10n.economyDropEndedHeadline, style: dropCapsStyle(color: DropPalette.inkMuted, spacing: 1.6)),
              const SizedBox(height: PrismSpace.lg),
              if (live && remaining > 0)
                _PriceTicket(drop: drop, remaining: remaining, isPro: isPro)
              else
                _Collected(owned: owned, count: drop.count),
            ],
          ),
        ),
      ),
    );
  }
}

class _Collected extends StatelessWidget {
  const _Collected({required this.owned, required this.count});

  final int owned;
  final int count;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        const Icon(Icons.verified_outlined, size: 16, color: DropPalette.gold),
        const SizedBox(width: PrismSpace.xs),
        Text(l10n.economyDropCollected(owned, count), style: dropCapsStyle(spacing: 1.4)),
      ],
    );
  }
}

class _PriceTicket extends StatelessWidget {
  const _PriceTicket({required this.drop, required this.remaining, required this.isPro});

  final DropEntity drop;
  final int remaining;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool pack = remaining > 1;
    final int saving = packSaving(drop, remaining: remaining, isPro: isPro);
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        painter: TicketPainter(
          fill: DropPalette.obsidianDeep.withValues(alpha: 0.7),
          stroke: DropPalette.hairlineStrong,
          dividerX: pack ? constraints.maxWidth / 2 : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm + 2, horizontal: PrismSpace.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _Price(
                  caption: isPro ? l10n.economyDropWallPro : l10n.economyDropWall,
                  price: drop.wallPrice(isPro: isPro),
                ),
              ),
              if (pack)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: PrismSpace.md),
                    child: _Price(
                      caption: l10n.economyDropPack,
                      price: drop.packPrice(remaining: remaining, isPro: isPro),
                      badge: saving > 0 ? l10n.economyDropSave(saving) : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.caption, required this.price, this.badge});

  final String caption;
  final int price;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(caption, style: dropCapsStyle(size: 10, spacing: 1.6, color: DropPalette.inkMuted)),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            const PrismCoinIcon(size: 18),
            const SizedBox(width: 6),
            Text(
              formatLocalizedNumber(price, context.l10n),
              style: const TextStyle(
                fontFamily: PrismFonts.fraunces,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 1,
                color: DropPalette.ink,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            if (badge != null) ...<Widget>[
              const SizedBox(width: PrismSpace.xs),
              Flexible(
                child: Text(badge!, style: dropCapsStyle(spacing: 0.4, color: DropPalette.goldLight)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
