import 'dart:math' as math;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/views/widgets/coin_gate_sheet.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Asks how to unlock [wall]: this one, or every wall left. A null [wall] asks only about every wall left, [locked].
/// [onUnlock] gets the wall id, or null for the pack. [onWatch] plays a rewarded ad; the sheet stays open and reads
/// the new balance.
Future<void> showDropUnlockSheet(
  BuildContext context, {
  required DropEntity drop,
  required DropWall? wall,
  required List<DropWall> locked,
  required void Function(String? wallId) onUnlock,
  required Future<void> Function() onWatch,
}) {
  final StackRouter router = context.router;
  return showPrismSheet<void>(
    context,
    builder: (sheetContext) => DropUnlockSheet(
      drop: drop,
      wall: wall,
      locked: locked,
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
    required this.locked,
    required this.onUnlock,
    required this.onWatch,
    required this.onEarn,
  });

  final DropEntity drop;
  final DropWall? wall;

  /// Every wall of the Drop the user does not own yet.
  final List<DropWall> locked;
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
    final AppLocalizations l10n = context.l10n;
    final bool isPro = app_state.prismUser.premium;
    final DropWall? wall = widget.wall;
    final int remaining = widget.locked.length;
    final int wallPrice = widget.drop.wallPrice(isPro: isPro);
    final int packPrice = widget.drop.packPrice(remaining: remaining, isPro: isPro);
    final List<DropWall> shownWalls = wall == null ? widget.locked.take(3).toList() : <DropWall>[wall];
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (context, balance, _) {
        final bool short = balance < (wall == null ? packPrice : wallPrice);
        return PrismSheetBody(
          title: wall == null || wall.title.isEmpty ? widget.drop.displayTitle(l10n) : wall.title,
          message: wall == null
              ? l10n.economyDropWallCount(remaining)
              : wall.by.isEmpty
              ? null
              : l10n.economyDropByCreator(wall.by),
          actions: <Widget>[
            if (wall != null)
              PrismButton(
                label: l10n.economyDropUnlockWall(wallPrice),
                expand: true,
                trailing: const PrismCoinIcon(size: 18),
                onPressed: _watching ? null : () => widget.onUnlock(wall.id),
              ),
            if (wall == null || remaining > 1)
              PrismButton(
                label: l10n.economyDropUnlockAll(remaining, packPrice),
                expand: true,
                variant: wall == null ? PrismButtonVariant.primary : PrismButtonVariant.tonal,
                trailing: const PrismCoinIcon(size: 18),
                onPressed: _watching ? null : () => widget.onUnlock(null),
              ),
            if (short)
              PrismButton(
                label: watchAdOptionLabel(l10n),
                expand: true,
                variant: PrismButtonVariant.tonal,
                loading: _watching,
                onPressed: _watching ? null : _watch,
              ),
            if (short)
              PrismButton(
                label: l10n.economyEarnCoins,
                expand: true,
                variant: PrismButtonVariant.ghost,
                onPressed: widget.onEarn,
              ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LayoutBuilder(
                builder: (context, constraints) {
                  if (shownWalls.isEmpty) return const SizedBox(height: _previewHeight);
                  final double gaps = PrismSpace.xs * (shownWalls.length - 1);
                  final double availableWidth = math.max(0, constraints.maxWidth - gaps);
                  final double tileWidth = math.min(_previewHeight * _wallAspect, availableWidth / shownWalls.length);
                  final double tileHeight = tileWidth / _wallAspect;
                  return SizedBox(
                    height: tileHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (final (int i, DropWall shown) in shownWalls.indexed)
                          Padding(
                            padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : PrismSpace.xs),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(PrismRadius.md),
                              child: SizedBox(
                                width: tileWidth,
                                height: tileHeight,
                                child: PrismImageTile(url: shown.thumb),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: PrismSpace.sm),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: PrismSpace.xs,
                runSpacing: PrismSpace.xs,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const PrismCoinIcon(size: 16),
                      const SizedBox(width: PrismSpace.xxs),
                      Text(l10n.economyYouHaveCoins(balance), style: PrismTextStyles.caption(context)),
                    ],
                  ),
                  if (isPro) PrismTag(label: l10n.economyProPrice, tone: PrismTone.accent),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static const double _previewHeight = 200;

  /// A phone wallpaper is about 9 by 19.5.
  static const double _wallAspect = 0.46;
}
