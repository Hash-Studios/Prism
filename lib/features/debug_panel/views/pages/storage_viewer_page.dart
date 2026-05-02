import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StorageViewerPage extends StatefulWidget {
  const StorageViewerPage({super.key});

  @override
  State<StorageViewerPage> createState() => _StorageViewerPageState();
}

class _StorageViewerPageState extends State<StorageViewerPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _allKeys = [];
  bool _loading = true;

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
    setState(() => _loading = true);
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
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<String> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _allKeys;
    return _allKeys.where((k) => k.toLowerCase().contains(q)).toList();
  }

  Future<void> _deleteKey(String key) async {
    await _store?.delete(key);
    await _loadKeys();
  }

  Future<void> _clearAll() async {
    await _store?.clearAll();
    await _loadKeys();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All storage cleared'), duration: Duration(seconds: 2)));
    }
  }

  void _showEditDialog(String key) {
    final raw = _store?.get(key);
    final valueStr = raw?.toString() ?? '';
    final ctrl = TextEditingController(text: valueStr);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(key, style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${raw?.runtimeType ?? "null"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 6,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder(), isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '$key\n$valueStr'));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
            },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await _store?.set(key, ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadKeys();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;
    final store = _store;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Filter keys...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear())
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh, size: 18), onPressed: _loadKeys),
              IconButton(
                tooltip: 'Clear All',
                icon: const Icon(Icons.delete_forever_outlined, size: 18, color: Colors.red),
                onPressed: store == null
                    ? null
                    : () => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear All Storage?'),
                          content: const Text(
                            'This will permanently delete all locally stored data. The app may behave unexpectedly until restarted.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _clearAll();
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(
            children: [
              Text('${filtered.length} keys', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              Text(
                'Backend: ${PersistenceRuntime.isInitialized ? PersistenceRuntime.backend.name : "unknown"}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (store == null)
          const Expanded(
            child: Center(
              child: Text('Storage not initialized', style: TextStyle(color: Colors.grey)),
            ),
          )
        else if (filtered.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No keys found', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final key = filtered[i];
                final raw = store.get(key);
                final valuePreview = _previewValue(raw);

                return ListTile(
                  dense: true,
                  title: Text(key, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  subtitle: Text(
                    valuePreview,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: 'Copy value',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: raw?.toString() ?? ''));
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
                        },
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete key?'),
                            content: Text('Delete "$key"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteKey(key);
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  onTap: () => _showEditDialog(key),
                );
              },
            ),
          ),
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
