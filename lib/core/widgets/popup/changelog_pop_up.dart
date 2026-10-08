import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/accent_color.dart';
import 'package:Prism/core/widgets/popup/popup_header.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum _ChangeType { feature, fix, improvement }

class _ChangeItem {
  final String text;
  final _ChangeType type;
  const _ChangeItem({required this.text, required this.type});
}

class _ChangelogVersion {
  final String version;
  final List<_ChangeItem> changes;
  const _ChangelogVersion({required this.version, required this.changes});
}

const String _changelogUrl = 'https://raw.githubusercontent.com/Hash-Studios/Prism/master/CHANGELOG.md';
const String _changelogCacheKey = 'remote_changelog_markdown_cache';

void showChangelog(BuildContext context, [VoidCallback? func]) {
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
          PopupHeader(
            width: MediaQuery.of(context).size.width * .78,
            child: Stack(
              children: [
                Center(child: Icon(JamIcons.refresh, color: Theme.of(context).colorScheme.secondary)),
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
          func?.call();
        },
        child: Text(
          'View full',
          style: TextStyle(fontSize: 14.0, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
        ),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: onColor(Theme.of(context).colorScheme.error),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () {
          if (navigator?.canPop() ?? false) {
            navigator?.pop();
          }
          func?.call();
        },
        child: const Text('Close', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
      ),
    ],
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    backgroundColor: Theme.of(context).primaryColor,
    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
  );
  showModal(context: context, builder: (BuildContext context) => aboutPopUp);
}

_ChangeType _inferChangeType(String text) {
  final value = text.toLowerCase();
  if (value.contains('fix') || value.contains('bug') || value.contains('crash')) {
    return _ChangeType.fix;
  }
  if (value.contains('improve') ||
      value.contains('optimiz') ||
      value.contains('performance') ||
      value.contains('refactor')) {
    return _ChangeType.improvement;
  }
  return _ChangeType.feature;
}

IconData _iconForType(_ChangeType type) {
  switch (type) {
    case _ChangeType.feature:
      return JamIcons.magic;
    case _ChangeType.fix:
      return JamIcons.bug;
    case _ChangeType.improvement:
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
      currentChanges.add(_ChangeItem(text: text, type: type));
    }
  }
  flushCurrent();

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
  List<_ChangelogVersion> _items = const <_ChangelogVersion>[];

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
    } catch (error, stackTrace) {
      logger.w('Changelog fetch failed', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.controller,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'The changelog could not be loaded.',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          for (int i = 0; i < _items.length; i++) ...[
            _ChangeVersion(number: _items[i].version, showDivider: i > 0),
            for (final item in _items[i].changes) _ChangeRow(text: item.text, type: item.type),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

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

class _ChangeRow extends StatelessWidget {
  final String text;
  final _ChangeType type;
  const _ChangeRow({required this.text, required this.type});

  Color _typeColor(BuildContext context) {
    switch (type) {
      case _ChangeType.feature:
        return accentColor(context);
      case _ChangeType.fix:
        return Colors.orange;
      case _ChangeType.improvement:
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
            child: Icon(_iconForType(type), size: 20, color: color),
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
