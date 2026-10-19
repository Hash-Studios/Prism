import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_catalog_resolver.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
import 'package:Prism/core/router/short_link_resolver.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:http/http.dart' as http;

/// Keeps the inviter of a referral link and claims the reward when the user is signed in.
Future<void> acceptReferralLink(String inviterId) async {
  await CoinsService.instance.setPendingReferralInviterId(inviterId);
  if (app_state.prismUser.loggedIn) {
    await CoinsService.instance.processPendingReferralIfEligible(inviterUserId: inviterId);
  } else {
    toasts.success('Referral saved. Sign in to claim +${CoinPolicy.referral} coins.', haptic: false);
  }
}

class DeepLinkNavigation {
  const DeepLinkNavigation({
    this.parser = const DeepLinkParser(),
    this.httpClient,
    this.onReferral = acceptReferralLink,
  });

  final DeepLinkParser parser;
  final http.Client? httpClient;
  final Future<void> Function(String inviterId) onReferral;

  static TargetTypeValue targetType(DeepLinkActionEntity action) => switch (action) {
    ShareLinkIntent() => TargetTypeValue.share,
    UserLinkIntent() => TargetTypeValue.user,
    SetupLinkIntent() => TargetTypeValue.setup,
    ReferLinkIntent() => TargetTypeValue.refer,
    ScreenLinkIntent() => TargetTypeValue.screen,
    PageLinkIntent() => switch (DeepLinkRouteCatalog.match(Uri.parse(action.path))?.target) {
      DeepLinkPageTarget.profile ||
      DeepLinkPageTarget.followers ||
      DeepLinkPageTarget.following => TargetTypeValue.user,
      DeepLinkPageTarget.wallpaperDetail => TargetTypeValue.share,
      _ => TargetTypeValue.screen,
    },
    ShortCodeIntent() => TargetTypeValue.shortCode,
    UnknownIntent() => TargetTypeValue.unknown,
  };

  bool isPrismDeepLink(Uri uri) {
    final String host = uri.host.toLowerCase();
    final String scheme = uri.scheme.toLowerCase();
    if ((scheme == 'https' || scheme == 'http') &&
        uri.userInfo.isEmpty &&
        (host == 'prismwalls.com' || host == 'www.prismwalls.com')) {
      return true;
    }
    return scheme == 'prism';
  }

  Future<DeepLinkRouteResolution> resolveAction(DeepLinkActionEntity action) async {
    if (action is ShortCodeIntent) {
      final result = await ShortLinkResolver(client: httpClient, parser: parser).resolve(action.code);
      return switch (result) {
        ShortLinkResolved(:final action) => resolveAction(action),
        ShortLinkFailed(:final reason, :final isNetwork) => DeepLinkRouteResolution.failure(
          reason,
          isNetwork: isNetwork,
        ),
      };
    }
    final PageRouteInfo? route = await mapActionToRoute(action);
    return route == null
        ? const DeepLinkRouteResolution.failure(AnalyticsReasonValue.missingData)
        : DeepLinkRouteResolution.route(route);
  }

  Future<PageRouteInfo?> mapActionToRoute(DeepLinkActionEntity action) async {
    switch (action) {
      case ShareLinkIntent():
        return WallpaperDetailRoute(
          wallId: action.wallId,
          source: action.source,
          thumbnailUrl: action.thumbnailUrl,
          analyticsSurface: AnalyticsSurfaceValue.shareWallpaperView,
        );
      case UserLinkIntent():
        return ProfileRoute(profileIdentifier: action.profileIdentifier);
      case SetupLinkIntent():
        toasts.error('Home screen setups are no longer available.', haptic: false);
        return const HomeTabRoute();
      case ReferLinkIntent():
        await onReferral(action.inviterId);
        return const RewardsTabRoute();
      case ScreenLinkIntent():
        return switch (action.screen) {
          DeepLinkScreen.shop => const ShopRoute(),
          DeepLinkScreen.drops => const DropsRoute(),
          DeepLinkScreen.leaderboard => const LeaderboardRoute(),
          DeepLinkScreen.draw => const DrawRoute(),
        };
      case ShortCodeIntent():
        return (await resolveAction(action)).route;
      case PageLinkIntent():
        return routeForPageLink(action);
      case UnknownIntent():
        return null;
    }
  }
}

class DeepLinkRouteResolution {
  const DeepLinkRouteResolution.route(this.route) : reason = null, isNetwork = false;
  const DeepLinkRouteResolution.failure(this.reason, {this.isNetwork = false}) : route = null;

  final PageRouteInfo? route;
  final AnalyticsReasonValue? reason;
  final bool isNetwork;
}
