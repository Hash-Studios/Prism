import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The fixed tip amounts. The server refuses any other amount.
const List<int> tipAmounts = <int>[10, 25, 50];

/// True when the signed-in viewer may tip [creatorUid]: never a guest, never their own account, and never a creator
/// they blocked or while the block list is still unknown. The server checks again.
bool canTipCreator(String? creatorUid, BlockedCreators blockedCreators) {
  final String uid = creatorUid?.trim() ?? '';
  final String viewer = app_state.prismUser.id.trim();
  return app_state.prismUser.loggedIn &&
      viewer.isNotEmpty &&
      uid.isNotEmpty &&
      uid != viewer &&
      blockedCreators is KnownBlockedCreators &&
      !blockedCreators.blocks(uid);
}

/// Opens the tip sheet. [source] is `wall` or `profile` for analytics; [wallId] is the wall document ID.
Future<void> showTipSheet(
  BuildContext context, {
  required String creatorUid,
  required String creatorName,
  required String source,
  String? wallId,
}) {
  PrismHaptics.tap();
  return showPrismSheet<void>(
    context,
    builder: (BuildContext sheetContext) =>
        TipSheet(creatorUid: creatorUid, creatorName: creatorName, source: source, wallId: wallId),
  );
}

enum _Stage { choose, sending, sent }

/// Picks a tip amount, shows the balance and the cost, and thanks the user once the coins move.
class TipSheet extends StatefulWidget {
  const TipSheet({super.key, required this.creatorUid, required this.creatorName, required this.source, this.wallId});

  final String creatorUid;
  final String creatorName;
  final String source;
  final String? wallId;

  @override
  State<TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends State<TipSheet> {
  _Stage _stage = _Stage.choose;
  int _amount = tipAmounts[1];
  int _sentAmount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(analytics.track(TipSheetOpenedEvent(source: widget.source)));
  }

  Future<void> _send() async {
    setState(() => _stage = _Stage.sending);
    final TipResult result = await CoinsService.instance.tipCreator(
      creatorUid: widget.creatorUid,
      amount: _amount,
      wallId: widget.wallId,
    );
    if (!mounted) return;
    if (result.outcome == TipOutcome.sent) {
      PrismHaptics.success();
      unawaited(analytics.track(TipSentEvent(amount: result.amount)));
      setState(() {
        _stage = _Stage.sent;
        _sentAmount = result.amount;
      });
      return;
    }
    unawaited(analytics.track(TipFailedEvent(reason: result.reason.isEmpty ? result.outcome.name : result.reason)));
    final AppLocalizations l10n = context.l10n;
    final String name = widget.creatorName;
    switch (result.outcome) {
      case TipOutcome.insufficient:
        setState(() => _stage = _Stage.choose);
        toasts.error(l10n.tipNotEnoughCoins);
        return;
      case TipOutcome.dailyLimit:
        toasts.info(l10n.tipDailyLimit);
      case TipOutcome.pairLimit:
        toasts.info(l10n.tipPairLimit(name));
      case TipOutcome.creatorLimit:
        toasts.info(l10n.tipCreatorLimit(name));
      case TipOutcome.senderTooNew:
        toasts.info(l10n.tipSenderTooNew);
      case TipOutcome.senderIneligible:
        toasts.info(l10n.tipSenderIneligible);
      case TipOutcome.blocked || TipOutcome.unavailable:
        toasts.info(l10n.tipUnavailable(name));
      case TipOutcome.sent || TipOutcome.failed:
        toasts.error(l10n.tipFailed);
    }
    Navigator.of(context).pop();
  }

  void _earnCoins() {
    final StackRouter router = context.router;
    Navigator.of(context).pop();
    router.pushPath('/rewards');
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (_stage == _Stage.sent) {
      return PrismSheetBody(
        mood: GlintMood.celebrate,
        centered: true,
        title: l10n.tipThanksTitle,
        message: l10n.tipThanksMessage(widget.creatorName, _sentAmount),
        actions: <Widget>[PrismButton(label: l10n.tipDone, expand: true, onPressed: () => Navigator.of(context).pop())],
      );
    }
    final bool sending = _stage == _Stage.sending;
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (BuildContext context, int balance, _) {
        final bool short = balance < _amount;
        final TextTheme text = Theme.of(context).textTheme;
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return PopScope(
          canPop: !sending,
          child: PrismSheetBody(
            title: l10n.tipTitle(widget.creatorName),
            message: l10n.tipMessage(widget.creatorName),
            actions: <Widget>[
              PrismButton(
                label: l10n.tipSendButton(_amount),
                expand: true,
                loading: sending,
                onPressed: short || sending ? null : _send,
              ),
              if (short)
                PrismButton(
                  label: l10n.tipEarnCoins,
                  expand: true,
                  variant: PrismButtonVariant.ghost,
                  onPressed: _earnCoins,
                ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  label: l10n.tipAmountsLabel,
                  container: true,
                  child: Wrap(
                    spacing: PrismSpace.sm,
                    runSpacing: PrismSpace.sm,
                    children: <Widget>[
                      for (final int amount in tipAmounts)
                        Semantics(
                          selected: amount == _amount,
                          button: true,
                          label: l10n.economyPriceCoins(amount),
                          excludeSemantics: true,
                          child: PrismChip(
                            label: '$amount',
                            leading: const PrismCoinIcon(size: 16),
                            selected: amount == _amount,
                            onTap: sending
                                ? null
                                : () {
                                    PrismHaptics.selection();
                                    setState(() => _amount = amount);
                                  },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: PrismSpace.md),
                Text(l10n.tipBalance(balance), style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                if (short)
                  Padding(
                    padding: const EdgeInsets.only(top: PrismSpace.xs),
                    child: Text(
                      l10n.tipShortBy(_amount - balance),
                      style: text.bodyMedium?.copyWith(color: scheme.error),
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
