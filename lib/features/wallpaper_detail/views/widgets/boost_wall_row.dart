import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
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

/// "Boost to Trending" for the owner of an approved wall: 24 hours at the front of Trending for coins.
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

  String _time(DateTime when) => DateFormat.MMMd().add_jm().format(when.toLocal());

  Future<void> _boost() async {
    if (_busy) return;
    if (_active) {
      toasts.info('Already boosted until ${_time(_boostedUntil!)}.');
      return;
    }
    final bool confirmed = await showPrismConfirm(
      context,
      title: 'Boost to Trending',
      message: 'Put this wallpaper at the top of Trending for 24 hours for ${CoinPolicy.boostWall} coins.',
      confirmLabel: 'Boost for ${CoinPolicy.boostWall} coins',
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
        toasts.success('Boosted. It is live in Trending.');
      case BoostOutcome.active:
        toasts.info('Already boosted.');
      case BoostOutcome.slotsFull:
        final DateTime? next = result.nextFreeAt;
        toasts.error(
          next == null
              ? 'All boost slots are taken. Try again later.'
              : 'All boost slots are taken. The next one frees up ${_time(next)}.',
        );
      case BoostOutcome.insufficient:
        toasts.error('Not enough coins. Earn coins in Rewards.');
      case BoostOutcome.notOwner:
      case BoostOutcome.notApproved:
        toasts.error('Only approved wallpapers you uploaded can be boosted.');
      case BoostOutcome.failed:
        toasts.error("Couldn't boost this wallpaper. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? until = _boostedUntil;
    return PrismRow(
      icon: Icons.bolt_rounded,
      title: 'Boost to Trending',
      subtitle: _active && until != null
          ? 'Boosted until ${_time(until)}'
          : '24 hours at the top · ${CoinPolicy.boostWall} coins',
      onTap: _busy ? null : () => unawaited(_boost()),
    );
  }
}
