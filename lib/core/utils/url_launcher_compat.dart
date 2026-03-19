import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

typedef LaunchMode = launcher.LaunchMode;

const DeepLinkNavigation _deepLinkNavigation = DeepLinkNavigation();

Future<bool> launch(String url) {
  return launcher.launchUrl(Uri.parse(url));
}

Future<bool> openPrismLink(BuildContext context, String url, {LaunchMode mode = LaunchMode.platformDefault}) async {
  final Uri? parsed = Uri.tryParse(url.trim());
  if (parsed == null) {
    return false;
  }

  if (_deepLinkNavigation.isPrismDeepLink(parsed)) {
    final PageRouteInfo? route = await _deepLinkNavigation.mapUriToRoute(parsed);
    if (!context.mounted) {
      return false;
    }
    context.router.navigate(route ?? const NotFoundRoute());
    return true;
  }

  return launcher.launchUrl(parsed, mode: mode);
}

Future<bool> launchUrl(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) {
  return launcher.launchUrl(url, mode: mode);
}
