import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Confirms a 24 hour Pro pass for another user and sends it.
class GiftPassSheet extends StatefulWidget {
  const GiftPassSheet({super.key, required this.recipientUid, required this.recipientName});

  final String recipientUid;
  final String recipientName;

  @override
  State<GiftPassSheet> createState() => _GiftPassSheetState();
}

class _GiftPassSheetState extends State<GiftPassSheet> {
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final GiftResult result = await CoinsService.instance.giftPremiumPass(widget.recipientUid);
    if (result.outcome == GiftOutcome.sent) {
      unawaited(analytics.track(GiftSentEvent(recipientUid: widget.recipientUid)));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    final String name = widget.recipientName;
    switch (result.outcome) {
      case GiftOutcome.sent:
        toasts.success('Pass sent to $name.');
      case GiftOutcome.insufficient:
        toasts.error('Not enough coins. Earn coins in Rewards.');
      case GiftOutcome.limit:
        toasts.info('Gift limit reached for now. Try again tomorrow.');
      case GiftOutcome.recipientPremium:
        toasts.info('$name already has Pro.');
      case GiftOutcome.senderTooNew:
        toasts.info('Gifts open when your account is 7 days old.');
      case GiftOutcome.blocked:
        toasts.info("You can't send a gift to this account.");
      case GiftOutcome.failed:
        toasts.error("Couldn't send the gift. Try again.");
    }
  }

  void _earnCoins() {
    final StackRouter router = context.router;
    Navigator.of(context).pop();
    router.pushPath('/rewards');
  }

  @override
  Widget build(BuildContext context) {
    final int price = CoinPolicy.giftPremiumPass;
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (BuildContext context, int balance, _) {
        final bool short = balance < price;
        return PopScope(
          canPop: !_sending,
          child: PrismSheetBody(
            title: 'Gift a 24-hour Pro pass',
            message:
                '${widget.recipientName} gets premium collections and premium walls until tomorrow. '
                'Costs $price coins.',
            actions: <Widget>[
              PrismButton(label: 'Send gift', expand: true, loading: _sending, onPressed: short ? null : _send),
              if (short)
                PrismButton(
                  label: 'Earn coins',
                  expand: true,
                  variant: PrismButtonVariant.ghost,
                  onPressed: _earnCoins,
                ),
            ],
          ),
        );
      },
    );
  }
}
