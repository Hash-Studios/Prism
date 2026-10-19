import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
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
    final AppLocalizations l10n = context.l10n;
    Navigator.of(context).pop();
    final String name = widget.recipientName;
    switch (result.outcome) {
      case GiftOutcome.sent:
        toasts.success(l10n.accountPassSentToPerson(name));
      case GiftOutcome.insufficient:
        toasts.error(l10n.accountNotEnoughCoinsEarnInRewards);
      case GiftOutcome.limit:
        toasts.info(l10n.accountGiftLimitReached);
      case GiftOutcome.recipientPremium:
        toasts.info(l10n.accountPersonAlreadyHasPro(name));
      case GiftOutcome.senderTooNew:
        toasts.info(l10n.accountGiftsOpenAfterSevenDays);
      case GiftOutcome.blocked:
        toasts.info(l10n.accountCannotGiftThisAccount);
      case GiftOutcome.failed:
        toasts.error(l10n.accountCouldNotSendGift);
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
            title: context.l10n.accountGiftPassTitle,
            message: context.l10n.accountGiftPassMessage(widget.recipientName, price),
            actions: <Widget>[
              PrismButton(
                label: context.l10n.accountSendGift,
                expand: true,
                loading: _sending,
                onPressed: short ? null : _send,
              ),
              if (short)
                PrismButton(
                  label: context.l10n.accountEarnCoins,
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
