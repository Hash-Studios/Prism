import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const String _androidSubscriptionsUrl = 'https://play.google.com/store/account/subscriptions?package=com.hash.prism';
const String _iosSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions';

/// Opens the store page where the user changes or cancels a subscription. It shows a toast when that fails.
Future<void> openManageSubscription(AppLocalizations l10n) async {
  final String url = defaultTargetPlatform == TargetPlatform.iOS ? _iosSubscriptionsUrl : _androidSubscriptionsUrl;
  bool launched = false;
  try {
    launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    logger.w('Opening the subscription page failed.', error: e);
  }
  if (!launched) toasts.error(l10n.accountCouldNotOpenStore);
}
