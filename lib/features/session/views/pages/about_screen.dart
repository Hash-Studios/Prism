import 'dart:async';
import 'dart:io' show Platform;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/popup/changelog_pop_up.dart';
import 'package:Prism/core/widgets/popup/contri_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/views/widgets/prism_list.dart';
import 'package:Prism/features/session/data/report_problem_service.dart' show supportEmail;
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
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
      children: <Widget>[
        Image.asset('assets/images/prism.webp', height: 70),
        const SizedBox(height: PrismSpace.sm),
        Text('Prism Wallpapers', textAlign: TextAlign.center, style: PrismTextStyles.rowTitle(context)),
        Semantics(
          button: true,
          label: 'Version $_version',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onVersionTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                widthFactor: 1,
                child: Text('Version $_version', textAlign: TextAlign.center, style: PrismTextStyles.caption(context)),
              ),
            ),
          ),
        ),
        Text('A feature-rich wallpaper manager.', textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
        const SizedBox(height: PrismSpace.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: PrismSpace.xs,
          runSpacing: PrismSpace.xs,
          children: <Widget>[
            const ActionButton(
              icon: JamIcons.github,
              text: 'GITHUB',
              link: 'https://www.github.com/Hash-Studios/Prism',
            ),
            ActionButton(icon: Icons.star_rounded, text: 'RATE', link: _storeLink),
            ActionButton(
              icon: Icons.mail_outline_rounded,
              text: 'FEEDBACK',
              link: buildFeedbackLink(
                version: app_state.currentAppVersion,
                build: app_state.currentAppVersionCode,
                platform: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
              ),
              onLaunchFailed: (BuildContext context) =>
                  unawaited(showReportProblemSheet(context, source: 'about_feedback')),
            ),
            ActionButton(
              icon: Icons.refresh_rounded,
              text: "WHAT'S NEW",
              link: '',
              onTap: (BuildContext context) => showChangelog(context),
            ),
            const ActionButton(
              icon: Icons.privacy_tip_rounded,
              text: 'PRIVACY',
              link: 'https://prismwalls.com/privacy',
            ),
            const ActionButton(icon: Icons.description_rounded, text: 'TERMS', link: 'https://prismwalls.com/terms'),
            const ActionButton(icon: JamIcons.twitter, text: 'TWITTER', link: 'https://twitter.com/PrismWallpapers'),
            const ActionButton(
              icon: JamIcons.instagram,
              text: 'INSTAGRAM',
              link: 'https://www.instagram.com/prismwallpapers',
            ),
            const ActionButton(icon: JamIcons.paper_plane, text: 'TELEGRAM', link: 'http://t.me/PrismWallpapers'),
          ],
        ),
      ],
    );
  }

  Widget _hairline(BuildContext context) =>
      Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08));

  /// The top three as a podium (second, first, third, with the first largest), then everyone else in a group.
  Widget _team(BuildContext context, List<Contributor> contributors) {
    final List<Contributor> rest = contributors.skip(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (contributors.isEmpty)
          Text('No contributors to show yet.', style: PrismTextStyles.body(context))
        else
          Row(
            children: <Widget>[
              for (final (int rank, double size) in const <(int, double)>[(1, 70), (0, 90), (2, 70)])
                if (rank < contributors.length)
                  Expanded(
                    child: _TeamMember(contributor: contributors[rank], size: size),
                  ),
            ],
          ),
        if (rest.isNotEmpty) ...<Widget>[
          const SizedBox(height: PrismSpace.md),
          _hairline(context),
          const PrismSectionHeader(title: 'Other Contributors'),
          PrismGroup(
            children: <Widget>[
              for (final Contributor c in rest)
                PrismRow(
                  leading: PrismAvatar(url: c.avatarUrl, name: c.login, size: 40),
                  title: c.login ?? 'Contributor',
                  subtitle: _commits(c.contributions),
                  showChevron: false,
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

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'About',
      onBack: () {
        _trackAction(AnalyticsActionValue.backTapped, sourceContext: 'about_screen_close');
        context.router.maybePop();
      },
      bottomBar: Padding(
        padding: const EdgeInsets.only(top: PrismSpace.xs),
        child: Text(
          'Made with ❤ in India with Flutter!',
          textAlign: TextAlign.center,
          style: PrismTextStyles.caption(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.md, PrismSpace.page, PrismSpace.xl),
        children: <Widget>[
          _header(context),
          const SizedBox(height: PrismSpace.md),
          _hairline(context),
          const PrismSectionHeader(title: 'The Team'),
          FutureBuilder<List<Contributor>>(
            future: _contributors,
            builder: (context, snapshot) {
              final bool waiting =
                  snapshot.connectionState == ConnectionState.waiting ||
                  snapshot.connectionState == ConnectionState.none;
              if (waiting) {
                return const SizedBox(
                  height: 250,
                  child: GlintState(kind: GlintStateKind.loading, title: 'Loading the team'),
                );
              }
              _trackContributorsLoaded(snapshot);
              if (snapshot.hasError) {
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
              }
              return _team(context, snapshot.data ?? const <Contributor>[]);
            },
          ),
          const SizedBox(height: PrismSpace.md),
          _hairline(context),
          const SizedBox(height: PrismSpace.md),
          const PrismList(),
        ],
      ),
    );
  }
}

String _commits(int? count) => count == 1 ? '1 commit' : '${count ?? 0} commits';

class _TeamMember extends StatelessWidget {
  const _TeamMember({required this.contributor, required this.size});

  final Contributor contributor;
  final double size;

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
          child: Column(
            children: <Widget>[
              PrismAvatar(url: contributor.avatarUrl, name: login, size: size),
              const SizedBox(height: PrismSpace.xs),
              Text(
                login,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: PrismTextStyles.rowTitle(context),
              ),
              Text(
                _commits(contributor.contributions),
                textAlign: TextAlign.center,
                style: PrismTextStyles.caption(context),
              ),
            ],
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
    final String sourceContext = 'about_screen_action_chip_${text.toLowerCase()}';
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
