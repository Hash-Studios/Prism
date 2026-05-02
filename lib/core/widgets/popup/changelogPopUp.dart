import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/common/safe_rive_asset.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

enum ChangeType { feature, fix, improvement }

class _ChangeItem {
  final IconData icon;
  final String text;
  final ChangeType type;
  const _ChangeItem({required this.icon, required this.text, required this.type});
}

class _ChangelogVersion {
  final String version;
  final List<_ChangeItem> changes;
  const _ChangelogVersion({required this.version, required this.changes});
}

const String _changelogUrl = 'https://raw.githubusercontent.com/Hash-Studios/Prism/master/CHANGELOG.md';
const String _changelogCacheKey = 'remote_changelog_markdown_cache';

const List<_ChangelogVersion> _fallbackChangelog = [
  _ChangelogVersion(
    version: 'v2.6.9',
    changes: [
      _ChangeItem(icon: JamIcons.magic, text: 'AI-powered wallpaper generation pipeline.', type: ChangeType.feature),
      _ChangeItem(icon: JamIcons.coin, text: 'Coins economy — earn and spend coins in-app.', type: ChangeType.feature),
      _ChangeItem(icon: JamIcons.crown, text: 'Subscriptions and new paywall experience.', type: ChangeType.feature),
      _ChangeItem(icon: JamIcons.user_plus, text: 'All-new onboarding experience.', type: ChangeType.feature),
      _ChangeItem(
        icon: JamIcons.link,
        text: 'Deep links — open walls and profiles from URLs.',
        type: ChangeType.feature,
      ),
      _ChangeItem(icon: JamIcons.user, text: 'Profile completeness indicator.', type: ChangeType.improvement),
      _ChangeItem(icon: JamIcons.filter, text: 'Added 20+ new wallpaper filters.', type: ChangeType.improvement),
      _ChangeItem(icon: JamIcons.save, text: 'Save setups as drafts before uploading.', type: ChangeType.feature),
      _ChangeItem(icon: JamIcons.download, text: 'Fixed wallpaper download bugs.', type: ChangeType.fix),
      _ChangeItem(icon: JamIcons.eye, text: 'New splash screen animation.', type: ChangeType.improvement),
    ],
  ),
  _ChangelogVersion(
    version: 'v2.6.8',
    changes: [
      _ChangeItem(icon: JamIcons.user, text: 'All-new profile with cover photo and bio.', type: ChangeType.improvement),
      _ChangeItem(
        icon: JamIcons.instant_picture,
        text: 'Add icons with a single tap while submitting setups.',
        type: ChangeType.feature,
      ),
      _ChangeItem(icon: JamIcons.link, text: 'Add up to 25 links in your profile.', type: ChangeType.feature),
      _ChangeItem(icon: JamIcons.filter, text: 'Added 23 new filters like Rise, Ashby, etc.', type: ChangeType.feature),
      _ChangeItem(icon: JamIcons.bug, text: 'Fixed first-time app open stuck on splash screen.', type: ChangeType.fix),
    ],
  ),
  _ChangelogVersion(
    version: 'v2.6.7',
    changes: [
      _ChangeItem(icon: JamIcons.user, text: 'Add bio or change your username now!', type: ChangeType.feature),
      _ChangeItem(
        icon: JamIcons.log_in,
        text: 'Fix log-in bug affecting follows, favourites, and more.',
        type: ChangeType.fix,
      ),
    ],
  ),
  _ChangelogVersion(
    version: 'v2.6.6',
    changes: [
      _ChangeItem(icon: JamIcons.share, text: 'Fix share profile not working.', type: ChangeType.fix),
      _ChangeItem(icon: JamIcons.search, text: 'Local caching for search providers.', type: ChangeType.improvement),
      _ChangeItem(icon: JamIcons.bug, text: 'Minor bug fixes and improvements.', type: ChangeType.fix),
    ],
  ),
  _ChangelogVersion(
    version: 'v2.6.5',
    changes: [
      _ChangeItem(
        icon: JamIcons.user,
        text: 'New user model — username, photo, links and bio.',
        type: ChangeType.feature,
      ),
      _ChangeItem(icon: JamIcons.download, text: 'Download notifications.', type: ChangeType.feature),
      _ChangeItem(
        icon: JamIcons.refresh,
        text: 'Improved network requests with pagination.',
        type: ChangeType.improvement,
      ),
      _ChangeItem(icon: JamIcons.bug, text: 'Major bug fixes and improvements.', type: ChangeType.fix),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void showChangelog(BuildContext context, VoidCallback func) {
  final controller = ScrollController();
  final NavigatorState? navigator = Navigator.maybeOf(context, rootNavigator: true);
  final AlertDialog aboutPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header — animation + version label
          Container(
            height: 150,
            width: MediaQuery.of(context).size.width * .78,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              color: Theme.of(context).hintColor,
            ),
            child: Stack(
              children: [
                SafeRiveAsset(
                  assetName: "assets/animations/Changelog.riv",
                  animations: const <String>["changelog"],
                  fallback: Center(child: Icon(JamIcons.refresh, color: Theme.of(context).colorScheme.secondary)),
                ),
                Positioned(
                  bottom: 10,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v$currentAppVersion',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable changelog list
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: Scrollbar(
              radius: const Radius.circular(500),
              thickness: 5,
              controller: controller,
              thumbVisibility: true,
              child: _ChangelogList(controller: controller),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          openPrismLink(context, "https://bit.ly/prismchanges");
          func();
        },
        child: Text(
          'VIEW FULL',
          style: TextStyle(fontSize: 14.0, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
        ),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () {
          if (navigator?.canPop() ?? false) {
            navigator?.pop();
          }
          func();
        },
        child: const Text(
          'CLOSE',
          style: TextStyle(fontSize: 14.0, color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    ],
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    backgroundColor: Theme.of(context).primaryColor,
    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
  );
  showModal(context: context, builder: (BuildContext context) => aboutPopUp);
}

ChangeType _inferChangeType(String text) {
  final value = text.toLowerCase();
  if (value.contains('fix') || value.contains('bug') || value.contains('crash')) {
    return ChangeType.fix;
  }
  if (value.contains('improve') ||
      value.contains('optimiz') ||
      value.contains('performance') ||
      value.contains('refactor')) {
    return ChangeType.improvement;
  }
  return ChangeType.feature;
}

IconData _iconForType(ChangeType type) {
  switch (type) {
    case ChangeType.feature:
      return JamIcons.magic;
    case ChangeType.fix:
      return JamIcons.bug;
    case ChangeType.improvement:
      return JamIcons.refresh;
  }
}

List<_ChangelogVersion> _parseChangelogMarkdown(String markdown) {
  final List<_ChangelogVersion> versions = <_ChangelogVersion>[];
  String? currentVersion;
  List<_ChangeItem> currentChanges = <_ChangeItem>[];

  void flushCurrent() {
    if (currentVersion == null || currentChanges.isEmpty) {
      return;
    }
    versions.add(_ChangelogVersion(version: currentVersion!, changes: currentChanges));
    currentVersion = null;
    currentChanges = <_ChangeItem>[];
  }

  final lines = markdown.split('\n');
  for (final raw in lines) {
    final line = raw.trim();
    if (line.startsWith('### ')) {
      flushCurrent();
      currentVersion = line.substring(4).trim();
      continue;
    }
    if (line.startsWith('- ') && currentVersion != null) {
      final text = line.substring(2).trim();
      if (text.isEmpty) {
        continue;
      }
      final type = _inferChangeType(text);
      currentChanges.add(_ChangeItem(icon: _iconForType(type), text: text, type: type));
    }
  }
  flushCurrent();

  if (versions.isEmpty) {
    return _fallbackChangelog;
  }
  return versions.take(5).toList(growable: false);
}

class _ChangelogList extends StatefulWidget {
  final ScrollController controller;
  const _ChangelogList({required this.controller});

  @override
  State<_ChangelogList> createState() => _ChangelogListState();
}

class _ChangelogListState extends State<_ChangelogList> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  List<_ChangelogVersion> _items = _fallbackChangelog;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRemoteChangelog());
  }

  Future<void> _loadRemoteChangelog() async {
    final cached = _settingsLocal.get<String?>(_changelogCacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      final parsedCached = _parseChangelogMarkdown(cached);
      if (mounted && parsedCached.isNotEmpty) {
        setState(() {
          _items = parsedCached;
        });
      }
    }

    try {
      final response = await http.get(Uri.parse(_changelogUrl)).timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode >= 300 || response.body.trim().isEmpty) {
        return;
      }
      final parsed = _parseChangelogMarkdown(response.body);
      if (parsed.isEmpty) {
        return;
      }
      await _settingsLocal.set(_changelogCacheKey, response.body);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = parsed;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.controller,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _items.length; i++) ...[
            _ChangeVersion(number: _items[i].version, showDivider: i > 0),
            for (final item in _items[i].changes) _ChangeRow(icon: item.icon, text: item.text, type: item.type),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Version header widget
// ---------------------------------------------------------------------------

class _ChangeVersion extends StatelessWidget {
  final String number;
  final bool showDivider;
  const _ChangeVersion({required this.number, this.showDivider = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 20,
            endIndent: 20,
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            children: [
              Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Change row widget
// ---------------------------------------------------------------------------

class _ChangeRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ChangeType type;
  const _ChangeRow({required this.icon, required this.text, required this.type});

  Color _typeColor(BuildContext context) {
    switch (type) {
      case ChangeType.feature:
        return context.prismModeStyleForContext() == "Dark" && context.prismIsAmoledDark()
            ? Theme.of(context).colorScheme.error == Colors.black
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.error;
      case ChangeType.fix:
        return Colors.orange;
      case ChangeType.improvement:
        return Theme.of(context).colorScheme.secondary.withValues(alpha: 0.65);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 20),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Public re-export for callers that use `Change` directly (backward compat)
// ---------------------------------------------------------------------------

/// Retained for backward compatibility. Prefer using the [showChangelog] data
/// model instead of constructing [Change] widgets manually.
class Change extends StatelessWidget {
  final IconData icon;
  final String text;
  const Change({required this.icon, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return _ChangeRow(icon: icon, text: text, type: ChangeType.feature);
  }
}
