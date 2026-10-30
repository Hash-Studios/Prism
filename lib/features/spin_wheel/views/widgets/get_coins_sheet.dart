import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// The short-balance flow: one sheet that offers a video for coins, then the video, then the credit.
Future<void> showGetCoinsSheet(
  BuildContext context, {
  required String message,
  required String sourceTag,
  required String upsellSource,
  int? cost,
}) async {
  final int? missing = cost == null ? null : (cost - CoinsService.instance.balanceNotifier.value).clamp(0, cost);
  final int? remainder = missing == null ? null : (missing - CoinsService.instance.adsRewardNow).clamp(0, missing);
  final bool watch =
      await showPrismSheet<bool>(
        context,
        builder: (BuildContext sheetContext) => PrismSheetBody(
          title: sheetContext.l10n.economyNotEnoughCoins,
          message: [
            message,
            if (missing != null && missing > 0) sheetContext.l10n.economyCoinsMissing(missing),
            if (remainder != null && remainder > 0 && CoinsService.instance.adsRemainingToday != 0)
              sheetContext.l10n.economyCoinsRemainAfterAd(remainder),
          ].join('\n'),
          mood: GlintMood.worried,
          centered: true,
          actions: <Widget>[
            if (CoinsService.instance.adsRemainingToday != 0)
              PrismButton(
                label: sheetContext.l10n.economyWatchAdForCoins(CoinsService.instance.adsRewardNow),
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
            PrismButton(
              label: sheetContext.l10n.economyNotNow,
              expand: true,
              variant: PrismButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ) ??
      false;
  if (!watch || !context.mounted) return;
  final String owner = app_state.prismUser.id;
  int creditedCoins = 0;
  final bool credited = await CoinGate.forContext(context).watchAdForCoins(
    sourceTag: sourceTag,
    upsellSource: upsellSource,
    isMounted: () => context.mounted,
    adErrorMessage: context.l10n.economyAdNotCompleted,
    onCredited: (amount) => creditedCoins = amount,
  );
  if (credited && context.mounted && owner == app_state.prismUser.id && creditedCoins > 0) {
    toasts.success(context.l10n.economyCoinsEarned(creditedCoins));
  }
}
