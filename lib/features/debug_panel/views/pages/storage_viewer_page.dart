import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/debug_panel/views/widgets/debug_widgets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

class StorageViewerPage extends StatefulWidget {
  const StorageViewerPage({super.key});

  @override
  State<StorageViewerPage> createState() => _StorageViewerPageState();
}

class _StorageViewerPageState extends State<StorageViewerPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _allKeys = [];
  bool _loading = true;
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  LocalStore? get _store {
    if (!PersistenceRuntime.isInitialized) return null;
    return getIt<LocalStore>();
  }

  @override
  void initState() {
    super.initState();
    _loadKeys();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final store = _store;
      if (store == null) {
        setState(() {
          _allKeys = [];
          _loading = false;
        });
        return;
      }
      final keys = await store.keys();
      keys.sort();
      setState(() {
        _allKeys = keys;
        _loading = false;
      });
    } catch (e, st) {
      logger.w('Failed to load storage keys', tag: 'DebugPanel', error: e, stackTrace: st);
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  List<String> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _allKeys;
    return _allKeys.where((k) => k.toLowerCase().contains(q)).toList();
  }

  Future<void> _deleteKey(String key) async {
    final bool ok = await showPrismConfirm(
      context,
      title: 'Delete key?',
      message: 'Delete "$key" from local storage.',
      confirmLabel: 'Delete key',
      destructive: true,
    );
    if (!ok) return;
    await _store?.delete(key);
    await _loadKeys();
  }

  Future<void> _clearAll() async {
    final bool ok = await showPrismConfirm(
      context,
      title: 'Clear all storage?',
      message: 'This permanently deletes all locally stored data. The app may behave unexpectedly until restarted.',
      confirmLabel: 'Clear all',
      destructive: true,
    );
    if (!ok) return;
    await _store?.clearAll();
    await _loadKeys();
    if (mounted) showDebugSnackBar(context, 'All storage cleared');
  }

  Future<void> _showEditSheet(String key) async {
    final raw = _store?.get(key);
    await showPrismSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditValueSheet(
        storageKey: key,
        type: '${raw?.runtimeType ?? 'null'}',
        initial: raw?.toString() ?? '',
        onSave: (String value) async {
          await _store?.set(key, value);
          await _loadKeys();
        },
      ),
    );
  }

  Widget _content(LocalStore? store, List<String> filtered) {
    if (_loading) return PrismSkeleton.rows(avatar: false);
    if (_failed) {
      return GlintState(
        kind: GlintStateKind.error,
        title: 'Could not read storage',
        body: 'Check the logs, then try again.',
        actionLabel: 'Try again',
        onAction: _loadKeys,
      );
    }
    if (store == null) {
      return const GlintState(kind: GlintStateKind.empty, title: 'Storage not initialized');
    }
    if (filtered.isEmpty) {
      return const GlintState(kind: GlintStateKind.empty, title: 'No keys found');
    }
    final Color hairline = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: PrismSpace.xl),
      itemCount: filtered.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: PrismSpace.page, endIndent: PrismSpace.page, color: hairline),
      itemBuilder: (context, i) {
        final String key = filtered[i];
        final Object? raw = store.get(key);
        return _KeyRow(
          storageKey: key,
          preview: _previewValue(raw),
          onTap: () => _showEditSheet(key),
          onCopy: () => copyToClipboard(context, raw?.toString() ?? ''),
          onDelete: () => _deleteKey(key),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;
    final store = _store;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.xs, 0),
          child: Row(
            children: [
              Expanded(
                child: DebugSearchField(controller: _searchCtrl, hintText: 'Filter keys'),
              ),
              const SizedBox(width: PrismSpace.xxs),
              PrismIconButton(tooltip: 'Refresh', icon: Icons.refresh_rounded, onPressed: _loadKeys),
              PrismIconButton(
                tooltip: 'Clear all',
                icon: Icons.delete_forever_outlined,
                color: cs.error,
                onPressed: store == null ? null : _clearAll,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filtered.length} keys · Backend: ${PersistenceRuntime.isInitialized ? PersistenceRuntime.store.runtimeType : 'unknown'}',
              style: PrismTextStyles.caption(context),
            ),
          ),
        ),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
        Expanded(child: _content(store, filtered)),
      ],
    );
  }

  String _previewValue(Object? raw) {
    if (raw == null) return 'null';
    final str = raw.toString();
    if (str.length > 80) return '${str.substring(0, 80)}…';
    return str;
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.storageKey,
    required this.preview,
    required this.onTap,
    required this.onCopy,
    required this.onDelete,
  });

  final String storageKey;
  final String preview;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: PrismSpace.page, right: PrismSpace.xs),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: PrismSpace.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storageKey, style: debugMono(context, size: 13)),
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PrismTextStyles.caption(context),
                        ),
                      ],
                    ),
                  ),
                ),
                PrismIconButton(tooltip: 'Copy value', icon: Icons.copy_rounded, iconSize: 20, onPressed: onCopy),
                PrismIconButton(
                  tooltip: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  iconSize: 20,
                  color: cs.error,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditValueSheet extends StatefulWidget {
  const _EditValueSheet({required this.storageKey, required this.type, required this.initial, required this.onSave});

  final String storageKey;
  final String type;
  final String initial;
  final Future<void> Function(String value) onSave;

  @override
  State<_EditValueSheet> createState() => _EditValueSheetState();
}

class _EditValueSheetState extends State<_EditValueSheet> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_ctrl.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      logger.w('Failed to save storage value', tag: 'DebugPanel', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _saving = false);
      showDebugSnackBar(context, 'Could not save the value', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismSheetBody(
      title: 'Edit value',
      scrollable: true,
      actions: [
        PrismButton(label: 'Save', expand: true, loading: _saving, onPressed: _save),
        PrismButton(
          label: 'Copy',
          expand: true,
          variant: PrismButtonVariant.tonal,
          onPressed: () => copyToClipboard(context, '${widget.storageKey}\n${widget.initial}'),
        ),
        PrismButton(
          label: 'Cancel',
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(widget.storageKey, style: debugMono(context, size: 13)),
          const SizedBox(height: 2),
          Text('Type: ${widget.type}', style: PrismTextStyles.caption(context)),
          const SizedBox(height: PrismSpace.md),
          PrismTextField(
            controller: _ctrl,
            label: 'Value',
            helper: 'Saving writes the value as text.',
            minLines: 3,
            maxLines: 6,
            autocorrect: false,
          ),
        ],
      ),
    );
  }
}
