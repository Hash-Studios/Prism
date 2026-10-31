import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

bool _isSignedInOwner(String owner) => app_state.prismUser.loggedIn && owner == app_state.prismUser.id;

Future<bool> signInForOriginal(
  BuildContext context, {
  required String url,
  required String? wallpaperId,
  required WallpaperSource? wallpaperSource,
}) {
  return requireSignedInAction(context);
}

Future<OriginalAccessQuote?> quoteOriginalWithConsent(
  BuildContext context, {
  required String url,
  required String? wallpaperId,
  required WallpaperSource? wallpaperSource,
  required OriginalAccessAction action,
  required String label,
  String? requestId,
  Future<OriginalAccessQuote> Function()? quoteProvider,
}) async {
  if (!await requireSignedInAction(context)) return null;
  final service = OriginalAccessService.instance;
  if (!OriginalAccessService.requiresGrant(url, wallpaperId, wallpaperSource)) {
    return const OriginalAccessQuote(0, 0);
  }
  final owner = app_state.prismUser.id;
  while (context.mounted && _isSignedInOwner(owner)) {
    final quote = await (quoteProvider?.call() ?? service.quote(wallpaperId: wallpaperId!, action: action));
    if (!context.mounted || !_isSignedInOwner(owner)) return null;
    CoinsService.instance.applyServerBalance(quote.currentBalance, ownerId: owner);
    if (quote.requiredCoins > 0) {
      final l10n = context.l10n;
      final enough = quote.currentBalance >= quote.requiredCoins;
      final adsAllowed =
          !enough && (CoinsService.instance.adsRemainingToday ?? 1) > 0 && await AdConsent.instance.ensure();
      if (!context.mounted || !_isSignedInOwner(owner)) return null;
      final choice = await showCoinGateSheet<CoinGateChoice>(
        context,
        title: enough ? label : l10n.economyNotEnoughCoins,
        cost: quote.requiredCoins,
        message: (_) => enough
            ? l10n.economyDownloadCost(label, quote.requiredCoins)
            : l10n.economyDownloadCoinsNeeded(
                quote.requiredCoins - quote.currentBalance,
                CoinsService.instance.adsRewardNow,
                adsAllowed ? 'true' : 'false',
                adsAllowed ? 'none' : 'disabled',
              ),
        options: [
          if (enough) CoinGateOption(label: label, value: CoinGateChoice.spend),
          if (adsAllowed) CoinGateOption(label: watchAdOptionLabel(l10n), value: CoinGateChoice.watchAd),
          CoinGateOption(label: l10n.economyUpgradeToPro, value: CoinGateChoice.upgrade, outlined: true),
        ],
      );
      if (!context.mounted || !_isSignedInOwner(owner)) return null;
      if (choice == CoinGateChoice.upgrade) {
        await PaywallOrchestrator.instance.presentOrRequireSignIn(
          context,
          placement: PaywallPlacement.mainUpsell,
          source: 'original_access',
        );
        return null;
      }
      if (choice == CoinGateChoice.watchAd) {
        final credited = await CoinGate.forContext(context).watchAdForCoins(
          sourceTag: 'original_access.rewarded_ad',
          upsellSource: 'original_access',
          isMounted: () => context.mounted && _isSignedInOwner(owner),
        );
        if (!credited) return null;
        continue;
      }
      if (choice != CoinGateChoice.spend) return null;
    }
    return quote;
  }
  return null;
}

Future<String?> resolveOriginalWithConsent(
  BuildContext context, {
  required String url,
  required String? wallpaperId,
  required WallpaperSource? wallpaperSource,
  required OriginalAccessAction action,
  required String label,
  String? requestId,
}) async {
  if (!await signInForOriginal(context, url: url, wallpaperId: wallpaperId, wallpaperSource: wallpaperSource) ||
      !context.mounted) {
    return null;
  }
  final owner = app_state.prismUser.id;
  while (context.mounted && _isSignedInOwner(owner)) {
    final quote = await quoteOriginalWithConsent(
      context,
      url: url,
      wallpaperId: wallpaperId,
      wallpaperSource: wallpaperSource,
      action: action,
      label: label,
      requestId: requestId,
    );
    if (quote == null || !context.mounted || !_isSignedInOwner(owner)) return null;
    try {
      final resolved = await OriginalAccessService.instance.resolve(
        url: url,
        wallpaperId: wallpaperId,
        wallpaperSource: wallpaperSource,
        action: action,
        requestId: requestId,
        maxCoins: quote.requiredCoins,
      );
      return context.mounted && _isSignedInOwner(owner) ? resolved : null;
    } on OriginalAccessInsufficientBalance {
      continue;
    }
  }
  return null;
}
