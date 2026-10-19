import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_dispatcher.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

const DeepLinkNavigation _deepLinkNavigation = DeepLinkNavigation();

/// Whether [uri] targets the app's routing surface. Custom-scheme links always do; opening validates their encoding.
/// Other Prism links, such as `/privacy` and `/terms`, are web pages.
bool opensInApp(Uri uri) {
  if (!_deepLinkNavigation.isPrismDeepLink(uri)) {
    return false;
  }
  if (uri.scheme.toLowerCase() == 'prism') {
    return true;
  }
  final DeepLinkActionEntity action = _deepLinkNavigation.parser.parse(uri);
  return action is! UnknownIntent;
}

Future<bool> openPrismLink(
  BuildContext context,
  String url, {
  launcher.LaunchMode mode = launcher.LaunchMode.platformDefault,
}) async {
  final Uri? parsed = Uri.tryParse(url.trim());
  if (parsed == null) {
    return false;
  }
  try {
    Uri.decodeComponent(parsed.host);
    parsed.pathSegments;
    parsed.queryParameters;
  } on FormatException {
    return false;
  }

  if (opensInApp(parsed)) {
    final DeepLinkDispatcher? dispatcher = DeepLinkDispatcher.maybeOf(context.router);
    if (dispatcher == null) return false;
    final DeepLinkDispatchResult result = await dispatcher.openUri(parsed, source: DeepLinkSourceValue.inApp);
    return result == DeepLinkDispatchResult.navigated || result == DeepLinkDispatchResult.deferred;
  }

  final bool isPrismWebPage = _deepLinkNavigation.isPrismDeepLink(parsed);
  return launcher.launchUrl(parsed, mode: isPrismWebPage ? launcher.LaunchMode.externalApplication : mode);
}
