import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/widgets/popup/changelog_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

typedef _ApiLink = ({IconData icon, String name, String url, LinkDestinationValue destination, String sourceContext});

const List<_ApiLink> _apiLinks = <_ApiLink>[
  (
    icon: JamIcons.picture,
    name: 'WallHaven API',
    url: 'https://wallhaven.cc/help/api',
    destination: LinkDestinationValue.external,
    sourceContext: 'profile_prism_list_api_wallhaven',
  ),
  (
    icon: JamIcons.camera,
    name: 'Pexels API',
    url: 'https://www.pexels.com/api/',
    destination: LinkDestinationValue.external,
    sourceContext: 'profile_prism_list_api_pexels',
  ),
  (
    icon: JamIcons.unsplash,
    name: 'Unsplash API',
    url: 'https://unsplash.com/developers',
    destination: LinkDestinationValue.external,
    sourceContext: 'profile_prism_list_api_unsplash',
  ),
  (
    icon: JamIcons.github,
    name: 'GitHub API',
    url: 'https://developer.github.com/v3/',
    destination: LinkDestinationValue.github,
    sourceContext: 'profile_prism_list_api_github',
  ),
];

/// The "More" list on the About page: changelog, share, privacy policy and wallpaper sources.
class PrismList extends StatelessWidget {
  const PrismList({super.key});

  String get _shareText => defaultTargetPlatform == TargetPlatform.iOS
      ? "Fall in love with your phone's personalization again! Check out Prism -\n$appStoreUrl"
      : 'Fall in love with Android customisation again! Check out Prism -\n$playStoreUrl';

  void _trackAction(AnalyticsActionValue action, {required String sourceContext}) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.profilePrismList,
          action: action,
          sourceContext: sourceContext,
        ),
      ),
    );
  }

  void _trackExternalLink(LinkDestinationValue destination, {required bool launched, required String sourceContext}) {
    unawaited(
      analytics.track(
        ExternalLinkOpenResultEvent(
          surface: AnalyticsSurfaceValue.profilePrismList,
          destination: destination,
          result: launched ? EventResultValue.success : EventResultValue.failure,
          reason: launched ? null : AnalyticsReasonValue.error,
          sourceContext: sourceContext,
        ),
      ),
    );
  }

  Future<void> _openApiLink(_ApiLink link) async {
    final bool launched = await launchUrl(Uri.parse(link.url));
    _trackExternalLink(link.destination, launched: launched, sourceContext: link.sourceContext);
  }

  void _showSources(BuildContext context) {
    showPrismSheet<void>(
      context: context,
      builder: (sheetContext) => PrismSheetBody(
        title: 'Wallpaper sources',
        message: 'Prism uses these services to bring you wallpapers.',
        child: Column(
          children: <Widget>[
            for (final _ApiLink link in _apiLinks)
              PrismRow(
                leading: Icon(link.icon, size: 22, color: Theme.of(sheetContext).colorScheme.onSurface),
                title: link.name,
                padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(sheetContext).pop();
                  unawaited(_openApiLink(link));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrismGroup(
      children: <Widget>[
        PrismRow(
          icon: Icons.new_releases_rounded,
          title: "What's new",
          subtitle: 'See the changelog',
          onTap: () {
            _trackAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_prism_list_whats_new');
            showChangelog(context);
          },
        ),
        PrismRow(
          icon: Icons.ios_share_rounded,
          title: 'Share Prism',
          subtitle: 'Send a link to a friend',
          showChevron: false,
          onTap: () async {
            _trackAction(AnalyticsActionValue.drawerSharePrismTapped, sourceContext: 'profile_prism_list_share');
            await ShareService.shareText(text: _shareText, context: context);
          },
        ),
        PrismRow(
          icon: Icons.privacy_tip_rounded,
          title: 'Privacy policy',
          subtitle: 'How Prism handles your data',
          onTap: () async {
            _trackAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_prism_list_privacy');
            final bool launched = await launchUrl(
              Uri.parse('https://github.com/Hash-Studios/Prism/tree/master/PRIVACY.md'),
            );
            _trackExternalLink(
              LinkDestinationValue.github,
              launched: launched,
              sourceContext: 'profile_prism_list_privacy',
            );
          },
        ),
        PrismRow(
          icon: Icons.collections_rounded,
          title: 'Wallpaper sources',
          subtitle: 'Prism uses Wallhaven and Pexels for wallpapers',
          onTap: () {
            _trackAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_prism_list_api');
            _showSources(context);
          },
        ),
      ],
    );
  }
}
