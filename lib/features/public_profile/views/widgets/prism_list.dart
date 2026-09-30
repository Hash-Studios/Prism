import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/popup/changelog_pop_up.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class PrismList extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PrismListTile(
          icon: JamIcons.info,
          title: "What's new?",
          subtitle: 'Check out the changelog',
          onTap: () {
            _trackAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_prism_list_whats_new');
            showChangelog(context, () {});
          },
        ),
        _PrismListTile(
          icon: JamIcons.share_alt,
          title: 'Share Prism!',
          subtitle: 'Quick link to pass on to your friends and enemies',
          onTap: () async {
            _trackAction(AnalyticsActionValue.drawerSharePrismTapped, sourceContext: 'profile_prism_list_share');
            await ShareService.shareText(text: _shareText, context: context);
          },
        ),
        _PrismListTile(
          icon: JamIcons.users,
          title: 'Privacy Policy',
          subtitle: "Read Prism's Privacy Policy.",
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
        _PrismListTile(
          icon: JamIcons.picture,
          title: 'API',
          subtitle: 'Prism uses Wallhaven and Pexels API for wallpapers',
          onTap: () {
            _trackAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_prism_list_api');
            showModal(
              context: context,
              builder: (context) => AlertDialog(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                content: SizedBox(
                  height: 280,
                  width: 250,
                  child: Center(
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final _ApiLink link in _apiLinks)
                          ListTile(
                            leading: Icon(link.icon, color: Theme.of(context).colorScheme.secondary),
                            title: Text(link.name, style: Theme.of(context).textTheme.headlineMedium),
                            onTap: () {
                              HapticFeedback.vibrate();
                              Navigator.of(context).pop();
                              unawaited(_openApiLink(link));
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PrismListTile extends StatelessWidget {
  const _PrismListTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w500,
          fontFamily: PrismFonts.proximaNova,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
