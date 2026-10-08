import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

const DeepLinkNavigation _deepLinkNavigation = DeepLinkNavigation();

/// True when the app opens [uri] on its own screens. Other Prism links, such as `/privacy` and `/terms`, are web pages.
bool opensInApp(Uri uri) {
  if (!_deepLinkNavigation.isPrismDeepLink(uri)) {
    return false;
  }
  if (uri.scheme.toLowerCase() == 'prism') {
    return true;
  }
  final DeepLinkActionEntity action = _deepLinkNavigation.parser.parse(_deepLinkNavigation.parser.transform(uri));
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

  if (opensInApp(parsed)) {
    final PageRouteInfo? route = await _deepLinkNavigation.mapUriToRoute(parsed);
    if (!context.mounted) {
      return false;
    }
    context.router.navigate(route ?? const NotFoundRoute());
    return true;
  }

  final bool isPrismWebPage = _deepLinkNavigation.isPrismDeepLink(parsed);
  return launcher.launchUrl(parsed, mode: isPrismWebPage ? launcher.LaunchMode.externalApplication : mode);
}
