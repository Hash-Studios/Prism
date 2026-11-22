import 'package:Prism/core/widgets/prism_sheet/prism_sheet_route.dart';
import 'package:Prism/features/coin_packs/data/coin_pack_gateway.dart';
import 'package:Prism/features/coin_packs/domain/coin_packs_flag.dart';
import 'package:Prism/features/coin_packs/views/coin_packs_sheet.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/widgets.dart';

export 'data/coin_pack_gateway.dart';
export 'domain/coin_pack.dart';
export 'domain/coin_packs_flag.dart';
export 'views/coin_packs_sheet.dart';

/// Opens the "Get coins" sheet. [source] names the entry point for analytics, for example `download_gate`.
/// [message] is the reason shown above the packs, for example the short-balance text. Does nothing when
/// [CoinPacksFlag.available] is false.
Future<void> showCoinPacksSheet(
  BuildContext context, {
  required String source,
  String? message,
  CoinPackGateway? gateway,
}) async {
  if (!CoinPacksFlag.available) return;
  await showPrismSheet<void>(
    context,
    builder: (BuildContext _) =>
        CoinPacksSheet(source: source, message: message, gateway: gateway ?? RevenueCatCoinPackGateway()),
  );
}

/// The short-balance answer for places that showed only a toast: the "Get coins" sheet with [message] when coin
/// packs are on, else the old error toast.
Future<void> showCoinShortfall(BuildContext context, {required String message, required String source}) async {
  if (!CoinPacksFlag.available) {
    toasts.error(message);
    return;
  }
  await showCoinPacksSheet(context, source: source, message: message);
}
