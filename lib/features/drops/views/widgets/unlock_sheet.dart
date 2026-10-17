import 'dart:ui' show ImageFilter;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/views/widgets/coin_gate_sheet.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Asks how to unlock [wall]: this one, or every wall left. [onUnlock] gets the wall id, or null for the pack.
/// [onWatch] plays a rewarded ad; the sheet stays open and reads the new balance.
Future<void> showDropUnlockSheet(
  BuildContext context, {
  required DropEntity drop,
  required DropWall wall,
  required int remaining,
  required void Function(String? wallId) onUnlock,
  required Future<void> Function() onWatch,
}) {
  final StackRouter router = context.router;
  return showPrismSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DropUnlockSheet(
      drop: drop,
      wall: wall,
      remaining: remaining,
      onUnlock: (wallId) {
        Navigator.of(sheetContext).pop();
        onUnlock(wallId);
      },
      onWatch: onWatch,
      onEarn: () {
        Navigator.of(sheetContext).pop();
        router.pushPath('/rewards');
      },
    ),
  );
}

class DropUnlockSheet extends StatefulWidget {
  const DropUnlockSheet({
    super.key,
    required this.drop,
    required this.wall,
    required this.remaining,
    required this.onUnlock,
    required this.onWatch,
    required this.onEarn,
  });

  final DropEntity drop;
  final DropWall wall;
  final int remaining;
  final void Function(String? wallId) onUnlock;
  final Future<void> Function() onWatch;
  final VoidCallback onEarn;

  @override
  State<DropUnlockSheet> createState() => _DropUnlockSheetState();
}

class _DropUnlockSheetState extends State<DropUnlockSheet> {
  bool _watching = false;

  Future<void> _watch() async {
    setState(() => _watching = true);
    try {
      await widget.onWatch();
    } finally {
      if (mounted) setState(() => _watching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPro = app_state.prismUser.premium;
    final int wallPrice = widget.drop.wallPrice(isPro: isPro);
    final int packPrice = widget.drop.packPrice(remaining: widget.remaining, isPro: isPro);
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (context, balance, _) {
        final bool short = balance < wallPrice;
        return PrismSheetBody(
          title: widget.wall.title.isEmpty ? widget.drop.title : widget.wall.title,
          message: widget.wall.by.isEmpty ? null : 'by ${widget.wall.by}',
          scrollable: true,
          actions: <Widget>[
            PrismButton(
              label: 'Unlock this wall for $wallPrice',
              expand: true,
              trailing: const PrismCoinIcon(size: 18),
              onPressed: _watching ? null : () => widget.onUnlock(widget.wall.id),
            ),
            if (widget.remaining > 1)
              PrismButton(
                label: 'Unlock the pack for $packPrice',
                expand: true,
                variant: PrismButtonVariant.tonal,
                trailing: const PrismCoinIcon(size: 18),
                onPressed: _watching ? null : () => widget.onUnlock(null),
              ),
            if (short)
              PrismButton(
                label: watchAdOptionLabel(),
                expand: true,
                variant: PrismButtonVariant.tonal,
                loading: _watching,
                onPressed: _watching ? null : _watch,
              ),
            if (short)
              PrismButton(
                label: 'Earn coins',
                expand: true,
                variant: PrismButtonVariant.ghost,
                onPressed: widget.onEarn,
              ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(PrismRadius.md),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: PrismImageTile(url: widget.wall.thumb),
                  ),
                ),
              ),
              const SizedBox(height: PrismSpace.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const PrismCoinIcon(size: 16),
                  const SizedBox(width: PrismSpace.xxs),
                  Text('You have $balance', style: PrismTextStyles.caption(context)),
                  if (isPro) ...<Widget>[
                    const SizedBox(width: PrismSpace.xs),
                    const PrismTag(label: 'Pro price', tone: PrismTone.accent),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
