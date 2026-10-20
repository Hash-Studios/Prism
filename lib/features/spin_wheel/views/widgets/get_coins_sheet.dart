import 'package:Prism/core/coins/coins_service.dart';
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
}) async {
  final bool watch =
      await showPrismSheet<bool>(
        context,
        builder: (BuildContext sheetContext) => PrismSheetBody(
          title: sheetContext.l10n.economyNotEnoughCoins,
          message: message,
          mood: GlintMood.worried,
          centered: true,
          actions: <Widget>[
            PrismButton(
              label: sheetContext.l10n.economyWatchVideoRewardCoins(CoinsService.instance.adsRewardNow),
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
  final int reward = CoinsService.instance.adsRewardNow;
  final bool credited = await CoinGate.forContext(context).watchAdForCoins(
    sourceTag: sourceTag,
    upsellSource: upsellSource,
    isMounted: () => context.mounted,
    adErrorMessage: context.l10n.economyAdNotCompleted,
  );
  if (credited) toasts.success(context.l10n.economyCoinsEarned(reward));
}
