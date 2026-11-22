import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_walls/data/creator_wall_unlocks.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Opens the unlock sheet for a priced [wall]. Resolves true when the wall was unlocked, false otherwise.
Future<bool> showCreatorWallUnlockSheet(
  BuildContext context, {
  required PrismWallpaper wall,
  CreatorWallUnlocks? unlocks,
}) async {
  PrismHaptics.tap();
  final bool? unlocked = await showPrismSheet<bool>(
    context,
    builder: (BuildContext sheetContext) => CreatorWallUnlockSheet(wall: wall, unlocks: unlocks),
  );
  return unlocked ?? false;
}

enum _Stage { choose, sending, unlocked }

/// Shows the price, the balance and the unlock action. Pays once through `unlockCreatorWall` and then shows the
/// unlocked moment. Pops true when the wall opened and false otherwise.
class CreatorWallUnlockSheet extends StatefulWidget {
  const CreatorWallUnlockSheet({
    super.key,
    required this.wall,
    @visibleForTesting this.unlock,
    @visibleForTesting this.balance,
    @visibleForTesting this.unlocks,
  });

  final PrismWallpaper wall;

  @visibleForTesting
  final Future<CreatorWallUnlockResult> Function({required String wallDocId, required int expectedPrice})? unlock;

  @visibleForTesting
  final ValueListenable<int>? balance;

  @visibleForTesting
  final CreatorWallUnlocks? unlocks;

  @override
  State<CreatorWallUnlockSheet> createState() => _CreatorWallUnlockSheetState();
}

class _CreatorWallUnlockSheetState extends State<CreatorWallUnlockSheet> {
  _Stage _stage = _Stage.choose;
  late int _currentPrice = widget.wall.creatorPrice;

  int get _price => _currentPrice;
  String get _wallDocId => widget.wall.firestoreDocumentId ?? '';

  @override
  void initState() {
    super.initState();
    unawaited(analytics.track(CreatorWallUnlockViewedEvent(price: _price)));
  }

  String _creatorName(AppLocalizations l10n) {
    final String name = widget.wall.core.authorName?.trim() ?? '';
    return name.isEmpty ? l10n.accountCreatorFallback : name;
  }

  Future<void> _unlock() async {
    setState(() => _stage = _Stage.sending);
    final AppLocalizations l10n = context.l10n;
    final String name = _creatorName(l10n);
    final CreatorWallUnlocks unlocks = widget.unlocks ?? CreatorWallUnlocks.instance;
    final String ownerUid = unlocks.currentOwner;
    late final CreatorWallUnlockResult result;
    try {
      result = await (widget.unlock ?? CoinsService.instance.unlockCreatorWall)(
        wallDocId: _wallDocId,
        expectedPrice: _price,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.choose);
      toasts.error(l10n.creatorWallUnlockFailed);
      return;
    }
    if (!mounted) return;
    unawaited(analytics.track(CreatorWallUnlockedEvent(price: _price, outcome: result.outcome.name)));
    if (result.unlocked) {
      unlocks.markUnlocked(_wallDocId, wallId: widget.wall.id, ownerUid: ownerUid);
      PrismHaptics.success();
      setState(() => _stage = _Stage.unlocked);
      return;
    }
    switch (result.outcome) {
      case CreatorWallUnlockOutcome.insufficient:
        setState(() => _stage = _Stage.choose);
        toasts.error(l10n.creatorWallNotEnoughCoins);
        return;
      case CreatorWallUnlockOutcome.priceChanged:
        if (result.price >= 10 && result.price <= 1000) {
          setState(() {
            _currentPrice = result.price;
            _stage = _Stage.choose;
          });
          toasts.info(l10n.creatorWallPriceChanged(result.price));
          return;
        }
        toasts.info(l10n.creatorWallUnlockFailed);
        Navigator.of(context).pop(false);
        return;
      case CreatorWallUnlockOutcome.dailyLimit:
        toasts.info(l10n.creatorWallDailyLimit);
      case CreatorWallUnlockOutcome.pairLimit:
        toasts.info(l10n.creatorWallPairLimit(name));
      case CreatorWallUnlockOutcome.creatorLimit:
        toasts.info(l10n.creatorWallCreatorLimit(name));
      case CreatorWallUnlockOutcome.buyerTooNew:
        toasts.info(l10n.creatorWallBuyerTooNew);
      case CreatorWallUnlockOutcome.buyerIneligible:
        toasts.info(l10n.creatorWallBuyerIneligible);
      case CreatorWallUnlockOutcome.unavailable:
        toasts.info(l10n.creatorWallUnavailable);
      case CreatorWallUnlockOutcome.unlocked ||
          CreatorWallUnlockOutcome.alreadyUnlocked ||
          CreatorWallUnlockOutcome.failed:
        toasts.error(l10n.creatorWallUnlockFailed);
    }
    Navigator.of(context).pop(false);
  }

  void _earnCoins() {
    final StackRouter router = context.router;
    Navigator.of(context).pop(false);
    router.pushPath('/rewards');
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (_stage == _Stage.unlocked) {
      return PrismSheetBody(
        mood: GlintMood.celebrate,
        centered: true,
        title: l10n.creatorWallUnlockedTitle,
        message: l10n.creatorWallUnlockedMessage,
        actions: <Widget>[
          PrismButton(label: l10n.creatorWallDone, expand: true, onPressed: () => Navigator.of(context).pop(true)),
        ],
      );
    }
    final bool sending = _stage == _Stage.sending;
    final ValueListenable<int> balance = widget.balance ?? CoinsService.instance.balanceNotifier;
    return ValueListenableBuilder<int>(
      valueListenable: balance,
      builder: (BuildContext context, int coins, _) {
        final bool short = coins < _price;
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return PopScope(
          canPop: !sending,
          child: PrismSheetBody(
            title: l10n.creatorWallUnlockTitle,
            message: l10n.creatorWallUnlockMessage(_creatorName(l10n)),
            actions: <Widget>[
              PrismButton(
                label: l10n.creatorWallUnlockButton(_price),
                expand: true,
                loading: sending,
                // Let the server answer idempotent retries even when the displayed balance is stale.
                onPressed: sending ? null : _unlock,
              ),
              if (short)
                PrismButton(
                  label: l10n.creatorWallGetCoins,
                  expand: true,
                  variant: PrismButtonVariant.ghost,
                  onPressed: _earnCoins,
                ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const PrismCoinIcon(size: 28),
                    const SizedBox(width: PrismSpace.xs),
                    Flexible(child: Text('$_price', style: PrismTextStyles.numeral(context, 40))),
                  ],
                ),
                const SizedBox(height: PrismSpace.md),
                Text(l10n.creatorWallBalance(coins), style: PrismTextStyles.caption(context)),
                if (short)
                  Padding(
                    padding: const EdgeInsets.only(top: PrismSpace.xs),
                    child: Text(
                      l10n.creatorWallShortBy(_price - coins),
                      style: PrismTextStyles.caption(context).copyWith(color: scheme.error),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
