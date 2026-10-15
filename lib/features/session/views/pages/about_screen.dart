import 'dart:async';
import 'dart:io' show Platform;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/popup/contri_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/views/widgets/prism_list.dart';
import 'package:Prism/features/session/data/report_problem_service.dart' show supportEmail;
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
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
Future<List<Contributor>> _fetchSessionContributors() {
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
  const AboutScreen({super.key, this.loadContributors});

  /// Replaces the GitHub lookup, for tests.
  final Future<List<Contributor>> Function()? loadContributors;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  int _versionTapCount = 0;

  late Future<List<Contributor>> _contributors = _fetchContributors();

  String get _storeLink => defaultTargetPlatform == TargetPlatform.iOS ? appStoreUrl : playStoreUrl;

  String get _version => '${app_state.currentAppVersion}+${app_state.currentAppVersionCode}';

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  void _onVersionTap() {
    Clipboard.setData(ClipboardData(text: _version));
    toasts.success('Version copied');
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

  Future<List<Contributor>> _fetchContributors() => widget.loadContributors?.call() ?? _fetchSessionContributors();

  void _trackContributorsLoaded(AsyncSnapshot<List<Contributor>> snapshot) {
    if (snapshot.hasError) {
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
      return;
    }
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
  }

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Glint(),
        const SizedBox(height: PrismSpace.md),
        Text('Prism', style: PrismTextStyles.sectionTitle(context)),
        Semantics(
          button: true,
          label: 'Version $_version. Tap to copy.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onVersionTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text('Version $_version', style: PrismTextStyles.caption(context)),
              ),
            ),
          ),
        ),
        Text('A feature-rich wallpaper manager.', style: PrismTextStyles.body(context)),
        const SizedBox(height: PrismSpace.md),
        Wrap(
          spacing: PrismSpace.xs,
          runSpacing: PrismSpace.xs,
          children: <Widget>[
            const ActionButton(
              icon: JamIcons.github,
              text: 'GitHub',
              link: 'https://www.github.com/Hash-Studios/Prism',
            ),
            ActionButton(icon: Icons.star_rounded, text: 'Rate Prism', link: _storeLink, analyticsName: 'rate'),
            const ActionButton(
              icon: JamIcons.twitter,
              text: 'X',
              link: 'https://twitter.com/PrismWallpapers',
              analyticsName: 'twitter',
            ),
            const ActionButton(
              icon: JamIcons.instagram,
              text: 'Instagram',
              link: 'https://www.instagram.com/prismwallpapers',
            ),
            ActionButton(
              icon: Icons.mail_outline_rounded,
              text: 'Feedback',
              link: buildFeedbackLink(
                version: app_state.currentAppVersion,
                build: app_state.currentAppVersionCode,
                platform: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
              ),
              onLaunchFailed: (BuildContext context) =>
                  unawaited(showReportProblemSheet(context, source: 'about_feedback')),
            ),
            const ActionButton(
              icon: Icons.privacy_tip_rounded,
              text: 'Privacy',
              link: 'https://prismwalls.com/privacy',
            ),
            const ActionButton(icon: Icons.description_rounded, text: 'Terms', link: 'https://prismwalls.com/terms'),
            const ActionButton(icon: JamIcons.paper_plane, text: 'Telegram', link: 'http://t.me/PrismWallpapers'),
          ],
        ),
      ],
    );
  }

  Widget _team(BuildContext context, List<Contributor> contributors) {
    final List<Contributor> top = contributors.take(3).toList(growable: false);
    final List<Contributor> rest = contributors.skip(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const PrismSectionHeader(title: 'Team'),
        if (top.isEmpty)
          Text('No contributors to show yet.', style: PrismTextStyles.body(context))
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[for (final Contributor c in top) _TeamMember(contributor: c)],
          ),
        if (rest.isNotEmpty) ...<Widget>[
          const PrismSectionHeader(title: 'Contributors'),
          PrismGroup(
            children: <Widget>[
              for (final Contributor c in rest)
                PrismRow(
                  leading: PrismAvatar(url: c.avatarUrl, name: c.login, size: 32),
                  title: c.login ?? 'Contributor',
                  subtitle: _commits(c.contributions),
                  onTap: () => _openContributorLink(c),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _openContributorLink(Contributor c) {
    PrismHaptics.tap();
    _trackAction(AnalyticsActionValue.contributorProfileTapped, sourceContext: 'about_screen_other_contributor');
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
  }

  Widget _teamLoading() {
    return PrismSkeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PrismSectionHeader(title: 'Team'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                const SizedBox(
                  width: 88,
                  child: Column(
                    children: <Widget>[
                      PrismBone.circle(size: 64),
                      SizedBox(height: PrismSpace.xs),
                      PrismBone(width: 64),
                      SizedBox(height: 6),
                      PrismBone(width: 48, height: 11),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamError(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismSectionHeader(title: 'Team'),
        Text("Couldn't load the team. Check your connection and try again.", style: PrismTextStyles.body(context)),
        const SizedBox(height: PrismSpace.sm),
        PrismButton(
          label: 'Try again',
          variant: PrismButtonVariant.tonal,
          size: PrismButtonSize.compact,
          onPressed: () => setState(() {
            _contributors = _fetchContributors();
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'About',
      onBack: () {
        _trackAction(AnalyticsActionValue.backTapped, sourceContext: 'about_screen_close');
        context.router.maybePop();
      },
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxxl),
        children: <Widget>[
          _header(context),
          FutureBuilder<List<Contributor>>(
            future: _contributors,
            builder: (context, snapshot) {
              final bool waiting =
                  snapshot.connectionState == ConnectionState.waiting ||
                  snapshot.connectionState == ConnectionState.none;
              if (waiting) return _teamLoading();
              _trackContributorsLoaded(snapshot);
              if (snapshot.hasError) return _teamError(context);
              return _team(context, snapshot.data ?? const <Contributor>[]);
            },
          ),
          const PrismSectionHeader(title: 'More'),
          const PrismList(),
          const SizedBox(height: PrismSpace.xl),
          Center(child: Text('Made in India with Flutter', style: PrismTextStyles.caption(context))),
        ],
      ),
    );
  }
}

String _commits(int? count) => count == 1 ? '1 commit' : '${count ?? 0} commits';

class _TeamMember extends StatelessWidget {
  const _TeamMember({required this.contributor});

  final Contributor contributor;

  @override
  Widget build(BuildContext context) {
    final String login = contributor.login ?? 'Contributor';
    return PressScale(
      child: Semantics(
        button: true,
        label: '$login, ${_commits(contributor.contributions)}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
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
            showContributorDetails(context, login);
          },
          child: SizedBox(
            width: 88,
            child: Column(
              children: <Widget>[
                PrismAvatar(url: contributor.avatarUrl, name: login, size: 64),
                const SizedBox(height: PrismSpace.xs),
                Text(
                  login,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.rowTitle(context),
                ),
                Text(_commits(contributor.contributions), style: PrismTextStyles.caption(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A link chip: an icon and a label that opens [link] and tracks the result.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.link,
    required this.text,
    this.analyticsName,
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

  /// Name used in the analytics source context. Defaults to the lower-case [text].
  final String? analyticsName;

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
    final String sourceContext = 'about_screen_action_chip_${analyticsName ?? text.toLowerCase()}';
    return PrismChip(
      label: text,
      icon: icon,
      onTap: () async {
        unawaited(
          analytics.track(
            SurfaceActionTappedEvent(
              surface: AnalyticsSurfaceValue.aboutScreen,
              action: AnalyticsActionValue.actionChipTapped,
              sourceContext: sourceContext,
            ),
          ),
        );
        final void Function(BuildContext context)? customTap = onTap;
        if (customTap != null) {
          customTap(context);
          return;
        }
        final String target = link.contains('@gmail.com') && !link.startsWith('mailto:') ? 'mailto:$link' : link;
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
              sourceContext: sourceContext,
            ),
          ),
        );
      },
    );
  }
}
