import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/original_access_prompt.dart';
import 'package:Prism/features/live_photo/views/live_photo_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// A Live Photo is a copy of the wall in Photos, so it follows the Download rules for Pro walls: they need Prism Pro
/// or an active premium pass.
bool livePhotoAllowed({required bool premiumWall, required bool premiumContentUnlocked}) =>
    !premiumWall || premiumContentUnlocked;

/// Opens the Live Photo flow for one wall. The user signs in first, a Pro wall asks for Pro, and a protected original
/// takes the same server grant as Download (`OriginalAccessAction.download`) when the user taps Save.
Future<void> openLivePhoto(
  BuildContext context, {
  required String url,
  required String wallId,
  required WallpaperSource? wallpaperSource,
  required bool premiumWall,
  ImageProvider? preview,
  String? depthMapUrl,
  Color? tint,
}) async {
  if (!await requireSignedInAction(context) || !context.mounted) return;
  bool allowed() =>
      livePhotoAllowed(premiumWall: premiumWall, premiumContentUnlocked: CoinsService.instance.premiumContentUnlocked);
  if (!allowed()) {
    await PaywallOrchestrator.instance.presentOrRequireSignIn(
      context,
      placement: PaywallPlacement.mainUpsell,
      source: 'live_photo',
    );
    if (!context.mounted || !allowed()) return;
  }
  final String label = context.l10n.livePhotoSave;
  await showLivePhotoSheet(
    context,
    wallId: wallId,
    preview: preview,
    depthMapUrl: depthMapUrl,
    tint: tint,
    resolveSource: () => resolveOriginalWithConsent(
      context,
      url: url,
      wallpaperId: wallId,
      wallpaperSource: wallpaperSource,
      action: OriginalAccessAction.download,
      label: label,
    ),
  );
}
