import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// True when the viewer owns this approved Prism wall and may pay to boost it. The server checks again.
bool canBoostWall(PrismWallpaper wall) {
  final String owner = wall.core.authorEmail?.trim().toLowerCase() ?? '';
  return app_state.prismUser.loggedIn &&
      wall.review == true &&
      owner.isNotEmpty &&
      owner == app_state.prismUser.email.trim().toLowerCase();
}

/// "Boost to Trending" for the owner of an approved wall: 24 hours in the Home carousel and at the top of Trending,
/// for coins.
class BoostWallRow extends StatefulWidget {
  const BoostWallRow({super.key, required this.wall});

  final PrismWallpaper wall;

  @override
  State<BoostWallRow> createState() => _BoostWallRowState();
}

class _BoostWallRowState extends State<BoostWallRow> {
  late DateTime? _boostedUntil = widget.wall.boostedUntil;
  bool _busy = false;

  bool get _active => _boostedUntil?.isAfter(DateTime.now()) ?? false;

  String _time(DateTime when, BuildContext context) =>
      DateFormat.MMMd(context.l10n.localeName).add_jm().format(when.toLocal());

  Future<void> _boost() async {
    if (_busy) return;
    if (_active) {
      toasts.info(context.l10n.wallpaperBoostAlreadyUntil(_time(_boostedUntil!, context)));
      return;
    }
    final bool confirmed = await showPrismConfirm(
      context,
      title: context.l10n.wallpaperBoostTitle,
      message: context.l10n.wallpaperBoostConfirmMessage(CoinPolicy.boostWall),
      confirmLabel: context.l10n.wallpaperBoostConfirmButton(CoinPolicy.boostWall),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final BoostResult result = await CoinsService.instance.boostWall(widget.wall.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.outcome == BoostOutcome.boosted || result.outcome == BoostOutcome.active) {
        _boostedUntil = result.endsAt ?? _boostedUntil;
      }
    });
    switch (result.outcome) {
      case BoostOutcome.boosted:
        unawaited(analytics.track(BoostPurchasedEvent(wallId: widget.wall.id)));
        toasts.success(context.l10n.wallpaperBoostedSuccess);
      case BoostOutcome.active:
        toasts.info(context.l10n.wallpaperBoostAlready);
      case BoostOutcome.slotsFull:
        final DateTime? next = result.nextFreeAt;
        toasts.error(
          next == null
              ? context.l10n.wallpaperBoostSlotsTaken
              : context.l10n.wallpaperBoostSlotsTakenUntil(_time(next, context)),
        );
      case BoostOutcome.insufficient:
        toasts.error(context.l10n.wallpaperInsufficientCoins);
      case BoostOutcome.notOwner:
      case BoostOutcome.notApproved:
        toasts.error(context.l10n.wallpaperBoostOnlyApproved);
      case BoostOutcome.failed:
        toasts.error(context.l10n.wallpaperBoostFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? until = _boostedUntil;
    return PrismRow(
      icon: Icons.bolt_rounded,
      title: context.l10n.wallpaperBoostTitle,
      subtitle: _active && until != null
          ? context.l10n.wallpaperBoostedUntil(_time(until, context))
          : context.l10n.wallpaperBoostDurationAndCost(CoinPolicy.boostWall),
      onTap: _busy ? null : () => unawaited(_boost()),
    );
  }
}
