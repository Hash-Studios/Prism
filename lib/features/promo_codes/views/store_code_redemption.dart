import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/promo_codes/domain/entities/promo_code.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final Uri playRedeemUri = Uri.parse('https://play.google.com/redeem');

/// Swapped in tests, which have no StoreKit or browser.
class StoreCodeIo {
  // The native sheet needs a configured RevenueCat; calling it before configuration ends the app, not a Dart error.
  Future<void> Function(String userId) ensureConfigured = PurchasesService.instance.ensureConfigured;
  Future<void> Function() presentAppStoreSheet = Purchases.presentCodeRedemptionSheet;
  Future<bool> Function(Uri uri) openExternal = (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
}

@visibleForTesting
final StoreCodeIo storeCodeIo = StoreCodeIo();

StoreCodePlatform get storeCodePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ? StoreCodePlatform.ios : StoreCodePlatform.android;

/// Opens the store's own code redemption: Apple's offer code sheet on iOS, Google Play's redeem page on Android.
Future<void> openStoreCodeRedemption(BuildContext context) async {
  final StoreCodePlatform platform = storeCodePlatform;
  final String failed = context.l10n.promoStoreCodeFailed;
  unawaited(analytics.track(StoreCodeSheetOpenedEvent(platform: platform)));
  try {
    final bool opened = switch (platform) {
      StoreCodePlatform.ios =>
        await storeCodeIo
            .ensureConfigured(app_state.prismUser.id)
            .timeout(const Duration(seconds: 10))
            .then((_) => storeCodeIo.presentAppStoreSheet())
            .then((_) => true),
      StoreCodePlatform.android => await storeCodeIo.openExternal(playRedeemUri),
    };
    if (!opened) toasts.error(failed);
  } catch (error) {
    logger.w('Store code redemption did not open.', error: error);
    toasts.error(failed);
  }
}
