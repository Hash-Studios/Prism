import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:flutter/material.dart';

/// Title, countdown and what a wall and the pack cost right now.
class DropHeader extends StatelessWidget {
  const DropHeader({super.key, required this.drop, required this.now, required this.remaining, required this.live});

  final DropEntity drop;
  final DateTime now;
  final int remaining;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final bool isPro = app_state.prismUser.premium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(drop.title, style: PrismTextStyles.sectionTitle(context)),
          const SizedBox(height: PrismSpace.xxs),
          Text(live ? drop.endsInLabel(now) : 'This Drop has ended', style: PrismTextStyles.caption(context)),
          if (live) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            Wrap(
              spacing: PrismSpace.md,
              runSpacing: PrismSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _Price(label: '${drop.wallPrice(isPro: isPro)} a wall'),
                if (remaining > 1)
                  _Price(
                    label: 'Pack ${drop.packPrice(remaining: remaining, isPro: isPro)}',
                  ),
                if (remaining == 0) Text('All unlocked', style: PrismTextStyles.caption(context)),
                if (isPro) const PrismTag(label: 'Pro price', tone: PrismTone.accent),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PrismCoinIcon(size: 16),
        const SizedBox(width: PrismSpace.xxs),
        Text(label, style: PrismTextStyles.rowTitle(context)),
      ],
    );
  }
}
