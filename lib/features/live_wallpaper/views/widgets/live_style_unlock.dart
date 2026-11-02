import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _UnlockChoice { coins, pro }

/// Paid live style id to the end of its coin unlock.
Map<String, DateTime> liveStyleUnlocks() => CoinsService.instance.currentPasses.liveStyles;

String liveMotionStyleLabel(AppLocalizations l10n, MotionStyle style) => switch (style) {
  MotionStyle.drift => l10n.wallpaperLiveStyleDrift,
  MotionStyle.breathe => l10n.wallpaperLiveStyleBreathe,
  MotionStyle.ripple => l10n.wallpaperLiveStyleRipple,
  MotionStyle.shimmer => l10n.wallpaperLiveStyleShimmer,
  MotionStyle.depth => l10n.wallpaperLiveStyleDepth,
};

/// Offers a coin unlock or Prism Pro for the paid live style [styleId]. Afterwards, read [liveStyleUnlocks] and the
/// user's Pro state again. [source] names the screen for the paywall.
Future<void> offerLiveStyleUnlock(
  BuildContext context, {
  required String styleId,
  required String label,
  required String source,
}) async {
  if (!await requireSignedInAction(context) || !context.mounted) return;
  final String owner = app_state.prismUser.id;
  final _UnlockChoice? choice = await showPrismSheet<_UnlockChoice>(
    context,
    builder: (sheetContext) => PrismSheetBody(
      title: context.l10n.wallpaperLiveUnlockStyleTitle(label),
      message: context.l10n.wallpaperLiveUnlockStyleBody,
      actions: <Widget>[
        PrismButton(
          label: context.l10n.wallpaperLiveUnlockStyleAction(
            label,
            NumberFormat.decimalPattern(context.l10n.localeName).format(CoinPolicy.liveWallpaperStyle),
          ),
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(_UnlockChoice.coins),
        ),
        PrismButton(
          label: context.l10n.wallpaperSeePrismPro,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: () => Navigator.of(sheetContext).pop(_UnlockChoice.pro),
        ),
      ],
    ),
  );
  if (!context.mounted || !app_state.prismUser.loggedIn || owner != app_state.prismUser.id || choice == null) return;
  switch (choice) {
    case _UnlockChoice.coins:
      final CoinMutationResult result = await CoinsService.instance.spend(
        CoinSpendAction.liveWallpaperStyle,
        styleId: styleId,
        sourceTag: 'live_wallpaper.style',
      );
      if (!context.mounted) return;
      if (result.success) {
        toasts.success(context.l10n.wallpaperLiveStyleUnlocked(label));
      } else if (result.insufficientBalance) {
        toasts.error(context.l10n.wallpaperInsufficientCoins);
      } else {
        toasts.error(context.l10n.wallpaperLiveUnlockError(label));
      }
    case _UnlockChoice.pro:
      await PaywallOrchestrator.instance.presentOrRequireSignIn(
        context,
        placement: PaywallPlacement.mainUpsell,
        source: source,
      );
  }
}
