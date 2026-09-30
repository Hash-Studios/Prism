import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/logger/logger.dart';
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

/// Opens the "What's new" sheet. [func] runs when the sheet closes.
void showChangelog(BuildContext context, [VoidCallback? func]) {
  showPrismSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85),
      child: PrismSheetBody(
        title: "What's new",
        message: 'You are on version $currentAppVersion.',
        scrollable: true,
        actions: <Widget>[
          PrismButton(
            label: 'See the full changelog',
            variant: PrismButtonVariant.ghost,
            expand: true,
            onPressed: () => openPrismLink(sheetContext, 'https://bit.ly/prismchanges'),
          ),
        ],
        child: const _ChangelogList(),
      ),
    ),
  ).whenComplete(() => func?.call());
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
      return Icons.auto_awesome_rounded;
    case _ChangeType.fix:
      return Icons.bug_report_rounded;
    case _ChangeType.improvement:
      return Icons.bolt_rounded;
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
  const _ChangelogList();

  @override
  State<_ChangelogList> createState() => _ChangelogListState();
}

class _ChangelogListState extends State<_ChangelogList> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  List<_ChangelogVersion> _items = const <_ChangelogVersion>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRemoteChangelog());
  }

  Future<void> _loadRemoteChangelog() async {
    if (!_loading) {
      setState(() => _loading = true);
    }
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
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return _loading
          ? SizedBox(height: 220, child: PrismSkeleton.rows(rows: 4, avatar: false, padding: EdgeInsets.zero))
          : GlintState(
              kind: GlintStateKind.error,
              title: 'Could not load the changelog',
              body: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => unawaited(_loadRemoteChangelog()),
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.md),
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < _items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: PrismSpace.xl),
          _ChangeVersion(number: _items[i].version, isLatest: i == 0),
          const SizedBox(height: PrismSpace.sm),
          for (int j = 0; j < _items[i].changes.length; j++) ...<Widget>[
            if (j > 0) const SizedBox(height: PrismSpace.sm),
            _ChangeRow(text: _items[i].changes[j].text, type: _items[i].changes[j].type),
          ],
        ],
      ],
    );
  }
}

class _ChangeVersion extends StatelessWidget {
  const _ChangeVersion({required this.number, required this.isLatest});

  final String number;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Flexible(child: Text(number, style: PrismTextStyles.cardTitle(context))),
        if (isLatest) ...<Widget>[
          const SizedBox(width: PrismSpace.xs),
          const PrismTag(label: 'Latest', tone: PrismTone.accent),
        ],
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.text, required this.type});

  final String text;
  final _ChangeType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(PrismRadius.xs),
          ),
          child: Icon(_iconForType(type), size: 16, color: cs.onSurface.withValues(alpha: 0.8)),
        ),
        const SizedBox(width: PrismSpace.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: PrismTextStyles.body(context).copyWith(color: cs.onSurface, height: 1.35)),
          ),
        ),
      ],
    );
  }
}
