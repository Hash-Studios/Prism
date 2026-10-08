import 'dart:async';
import 'dart:io' show Platform;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/popup/changelog_pop_up.dart';
import 'package:Prism/core/widgets/popup/contri_pop_up.dart';
import 'package:Prism/features/public_profile/views/widgets/prism_list.dart';
import 'package:Prism/features/session/data/report_problem_service.dart' show supportEmail;
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:github/github.dart';

/// A mailto link with the app version and platform in the body so reports carry the context.
@visibleForTesting
String buildFeedbackLink({required String version, required String build, required String platform}) {
  final String body = '\n\n---\nPrism $version+$build\n$platform';
  final String query = <String, String>{
    'subject': 'Prism feedback',
    'body': body,
  }.entries.map((MapEntry<String, String> e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  return 'mailto:$supportEmail?$query';
}

Future<List<Contributor>> _loadContributors() =>
    GitHub().repositories.listContributors(RepositorySlug('Hash-Studios', 'Prism')).toList();

/// Loads the contributor list. Tests replace it.
@visibleForTesting
Future<List<Contributor>> Function() contributorsLoader = _loadContributors;

Future<List<Contributor>>? _sessionContributors;
Future<List<Contributor>> Function()? _sessionLoader;

/// The GitHub API allows 60 unauthenticated requests per hour per IP, so the list loads once per session. A failed
/// load is not kept.
Future<List<Contributor>> _fetchContributors() {
  final Future<List<Contributor>>? cached = _sessionContributors;
  if (cached != null && identical(_sessionLoader, contributorsLoader)) return cached;
  final Future<List<Contributor>> loading = contributorsLoader();
  _sessionContributors = loading;
  _sessionLoader = contributorsLoader;
  unawaited(
    loading.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_sessionContributors, loading)) _sessionContributors = null;
      },
    ),
  );
  return loading;
}

/// Opens [target]. When nothing can open it, shows the address with a Copy action.
Future<bool> _openOrExplain(BuildContext context, String target, {required String address}) async {
  bool launched = false;
  try {
    launched = await openPrismLink(context, target);
  } catch (error, stackTrace) {
    logger.w('Opening $target failed.', error: error, stackTrace: stackTrace);
  }
  if (!launched && context.mounted) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text("Couldn't open $address"),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () => Clipboard.setData(ClipboardData(text: address)),
        ),
      ),
    );
  }
  return launched;
}

@RoutePage()
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  int _versionTapCount = 0;

  late Future<List<Contributor>> _contributors = _fetchContributors();

  String get _storeLink => defaultTargetPlatform == TargetPlatform.iOS ? appStoreUrl : playStoreUrl;

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  void _onVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      if (!app_state.isAdminUser()) return;
      PrismHaptics.impact();
      context.router.pushPath('/debug-panel');
    }
  }

  void _trackAction(AnalyticsActionValue action, {required String sourceContext}) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.aboutScreen,
          action: action,
          sourceContext: sourceContext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(JamIcons.close),
          onPressed: () {
            _trackAction(AnalyticsActionValue.backTapped, sourceContext: 'about_screen_close');
            Navigator.pop(context);
          },
        ),
        title: Text("About", style: Theme.of(context).textTheme.displaySmall),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: ListView(
          children: [
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.all(8.0), child: Image.asset("assets/images/prism.webp", height: 70)),
            const SizedBox(height: 10),
            Text(
              "Prism Wallpapers",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
            GestureDetector(
              onTap: _onVersionTap,
              child: Text(
                "Version ${app_state.currentAppVersion}+${app_state.currentAppVersionCode}",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "A feature-rich wallpaper manager.",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                const ActionButton(
                  icon: JamIcons.github,
                  text: "GITHUB",
                  link: "https://www.github.com/Hash-Studios/Prism",
                ),
                ActionButton(icon: JamIcons.star_full, text: "RATE", link: _storeLink),
                ActionButton(
                  icon: JamIcons.envelope,
                  text: "FEEDBACK",
                  link: buildFeedbackLink(
                    version: app_state.currentAppVersion,
                    build: app_state.currentAppVersionCode,
                    platform: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
                  ),
                  onLaunchFailed: (BuildContext context) =>
                      unawaited(showReportProblemSheet(context, source: 'about_feedback')),
                ),
                ActionButton(
                  icon: JamIcons.refresh,
                  text: "WHAT'S NEW",
                  link: '',
                  onTap: (BuildContext context) => showChangelog(context),
                ),
                const ActionButton(icon: JamIcons.users, text: "PRIVACY", link: "https://prismwalls.com/privacy"),
                const ActionButton(icon: JamIcons.file, text: "TERMS", link: "https://prismwalls.com/terms"),
                const ActionButton(
                  icon: JamIcons.twitter,
                  text: "TWITTER",
                  link: "https://twitter.com/PrismWallpapers",
                ),
                const ActionButton(
                  icon: JamIcons.instagram,
                  text: "INSTAGRAM",
                  link: "https://www.instagram.com/prismwallpapers",
                ),
                const ActionButton(icon: JamIcons.paper_plane, text: "TELEGRAM", link: "http://t.me/PrismWallpapers"),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            Container(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              width: MediaQuery.of(context).size.width * 0.9,
              child: Text("The Team", textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall),
            ),
            FutureBuilder<List<Contributor>>(
              future: _contributors,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.none) {
                  return const SizedBox(
                    height: 250,
                    child: GlintState(kind: GlintStateKind.loading, title: 'Loading the team'),
                  );
                } else if (snapshot.hasError) {
                  _contentLoadTracker.failure(
                    reason: AnalyticsReasonValue.error,
                    onFailure: ({required int loadTimeMs, AnalyticsReasonValue? reason, int? itemCount}) async {
                      await analytics.track(
                        SurfaceContentLoadedEvent(
                          surface: AnalyticsSurfaceValue.aboutScreen,
                          result: EventResultValue.failure,
                          loadTimeMs: loadTimeMs,
                          sourceContext: 'about_screen_contributors',
                          reason: reason,
                        ),
                      );
                    },
                  );
                  return SizedBox(
                    height: 250,
                    child: GlintState(
                      kind: GlintStateKind.error,
                      title: "Couldn't load the team",
                      actionLabel: 'Try again',
                      onAction: () => setState(() {
                        _contributors = _fetchContributors();
                      }),
                    ),
                  );
                } else {
                  _contentLoadTracker.success(
                    itemCount: snapshot.data?.length ?? 0,
                    onSuccess: ({required int loadTimeMs, int? itemCount}) async {
                      await analytics.track(
                        SurfaceContentLoadedEvent(
                          surface: AnalyticsSurfaceValue.aboutScreen,
                          result: (itemCount ?? 0) > 0 ? EventResultValue.success : EventResultValue.empty,
                          loadTimeMs: loadTimeMs,
                          sourceContext: 'about_screen_contributors',
                          itemCount: itemCount,
                        ),
                      );
                    },
                  );
                  final contributors = snapshot.data!;
                  final tiles = <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final (rank, radius) in const [(1, 35.0), (0, 45.0), (2, 35.0)])
                          if (rank < contributors.length)
                            _ContributorWidget(contributor: contributors[rank], radius: radius),
                      ],
                    ),
                    if (contributors.length > 3) ...[
                      const SizedBox(height: 10),
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: Text("Other Contributors", style: Theme.of(context).textTheme.displaySmall),
                      ),
                    ],
                    for (final Contributor c in contributors.skip(3))
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (c.avatarUrl ?? '').isEmpty
                              ? null
                              : CachedNetworkImageProvider(c.avatarUrl!),
                        ),
                        title: Text(
                          c.login ?? '',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        ),
                        subtitle: Text(
                          c.contributions == 1 ? "${c.contributions} commit" : "${c.contributions} commits",
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                          ),
                        ),
                        onTap: () {
                          PrismHaptics.tap();
                          _trackAction(
                            AnalyticsActionValue.contributorProfileTapped,
                            sourceContext: 'about_screen_other_contributor',
                          );
                          unawaited(() async {
                            final String profileUrl = c.htmlUrl ?? '';
                            final bool launched = await _openOrExplain(context, profileUrl, address: profileUrl);
                            await analytics.track(
                              ExternalLinkOpenResultEvent(
                                surface: AnalyticsSurfaceValue.aboutScreen,
                                destination: LinkDestinationValue.github,
                                result: launched ? EventResultValue.success : EventResultValue.failure,
                                reason: launched ? null : AnalyticsReasonValue.error,
                                sourceContext: 'about_screen_other_contributor',
                              ),
                            );
                          }());
                        },
                      ),
                  ];
                  return Column(children: tiles);
                }
              },
            ),
            const Divider(),
            PrismList(),
          ],
        ),
      ),
      bottomNavigationBar: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Made with ❤ in India with Flutter!",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
          ),
        ),
      ),
    );
  }
}

class _ContributorWidget extends StatelessWidget {
  const _ContributorWidget({required this.contributor, required this.radius});
  final Contributor contributor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        PrismHaptics.tap();
        unawaited(
          analytics.track(
            SurfaceActionTappedEvent(
              surface: AnalyticsSurfaceValue.aboutScreen,
              action: AnalyticsActionValue.contributorProfileTapped,
              sourceContext: 'about_screen_contributor',
              itemType: ItemTypeValue.user,
              itemId: contributor.login,
            ),
          ),
        );
        showContributorDetails(context, contributor.login ?? '');
      },
      child: Column(
        children: [
          CircleAvatar(backgroundImage: CachedNetworkImageProvider(contributor.avatarUrl ?? ""), radius: radius),
          const SizedBox(height: 5),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Text(
              contributor.login ?? '',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Text(
              "${contributor.contributions} commits",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.link,
    required this.text,
    this.onTap,
    this.onLaunchFailed,
  });
  final IconData icon;
  final String text;
  final String link;

  /// Runs instead of opening [link].
  final void Function(BuildContext context)? onTap;

  /// Runs instead of the Copy snackbar when [link] cannot be opened.
  final void Function(BuildContext context)? onLaunchFailed;

  LinkDestinationValue _destination() {
    final String lower = link.toLowerCase();
    if (lower.contains('github.com')) {
      return LinkDestinationValue.github;
    }
    if (lower.contains('play.google.com')) {
      return LinkDestinationValue.playStore;
    }
    if (lower.contains('twitter.com')) {
      return LinkDestinationValue.twitter;
    }
    if (lower.contains('instagram.com')) {
      return LinkDestinationValue.instagram;
    }
    if (lower.contains('t.me') || lower.contains('telegram')) {
      return LinkDestinationValue.telegram;
    }
    if (lower.contains('mailto:') || lower.contains('@gmail.com')) {
      return LinkDestinationValue.email;
    }
    return LinkDestinationValue.external;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ActionChip(
        avatar: Icon(icon, color: Theme.of(context).colorScheme.error),
        label: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          PrismHaptics.tap();
          unawaited(
            analytics.track(
              SurfaceActionTappedEvent(
                surface: AnalyticsSurfaceValue.aboutScreen,
                action: AnalyticsActionValue.actionChipTapped,
                sourceContext: 'about_screen_action_chip_${text.toLowerCase()}',
              ),
            ),
          );
          final void Function(BuildContext context)? customTap = onTap;
          if (customTap != null) {
            customTap(context);
            return;
          }
          final String target = link.contains("@gmail.com") && !link.startsWith('mailto:') ? "mailto:$link" : link;
          final Uri? targetUri = Uri.tryParse(target);
          final String address = targetUri != null && targetUri.scheme == 'mailto' ? targetUri.path : target;
          final bool launched;
          if (onLaunchFailed == null) {
            launched = await _openOrExplain(context, target, address: address);
          } else {
            bool opened = false;
            try {
              opened = await openPrismLink(context, target);
            } catch (error) {
              logger.w('Opening $target failed.', error: error);
            }
            launched = opened;
            if (!opened && context.mounted) onLaunchFailed!(context);
          }
          unawaited(
            analytics.track(
              ExternalLinkOpenResultEvent(
                surface: AnalyticsSurfaceValue.aboutScreen,
                destination: _destination(),
                result: launched ? EventResultValue.success : EventResultValue.failure,
                reason: launched ? null : AnalyticsReasonValue.error,
                sourceContext: 'about_screen_action_chip_${text.toLowerCase()}',
              ),
            ),
          );
        },
      ),
    );
  }
}
