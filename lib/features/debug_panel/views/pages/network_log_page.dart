import 'dart:async';

import 'package:Prism/core/debug/network_log_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NetworkLogPage extends StatefulWidget {
  const NetworkLogPage({super.key});

  @override
  State<NetworkLogPage> createState() => _NetworkLogPageState();
}

class _NetworkLogPageState extends State<NetworkLogPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<NetworkLogEntry>? _sub;
  List<NetworkLogEntry> _entries = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _entries = List<NetworkLogEntry>.from(NetworkLogStore.instance.entries);
    _sub = NetworkLogStore.instance.stream.listen((_) {
      if (!mounted) return;
      setState(() {
        _entries = List<NetworkLogEntry>.from(NetworkLogStore.instance.entries);
      });
    });
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<NetworkLogEntry> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries.where((e) => e.url.toLowerCase().contains(q) || e.method.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;

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
                    hintText: 'Filter by URL or method...',
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
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () {
                  NetworkLogStore.instance.clear();
                  setState(() => _entries.clear());
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(children: [Text('${filtered.length} requests', style: Theme.of(context).textTheme.bodySmall)]),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No requests captured', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    // Show newest first.
                    final entry = filtered[filtered.length - 1 - i];
                    return _NetworkEntryTile(entry: entry);
                  },
                ),
        ),
      ],
    );
  }
}

class _NetworkEntryTile extends StatelessWidget {
  const _NetworkEntryTile({required this.entry});
  final NetworkLogEntry entry;

  Color get _statusColor {
    if (entry.isPending) return Colors.grey;
    if (entry.isError) return Colors.red;
    return Colors.green;
  }

  String get _statusLabel {
    if (entry.isPending) return '...';
    if (entry.error != null) return 'ERR';
    return '${entry.statusCode}';
  }

  String get _method => entry.method;

  Color get _methodColor {
    switch (entry.method.toUpperCase()) {
      case 'GET':
        return Colors.blue;
      case 'POST':
        return Colors.green;
      case 'PUT':
      case 'PATCH':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(entry.url);
    final displayUrl = uri != null ? '${uri.host}${uri.path}' : entry.url;
    final elapsed = entry.elapsedMs != null ? '${entry.elapsedMs}ms' : '';

    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).primaryColor,
        builder: (_) => _NetworkDetailSheet(entry: entry),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: _methodColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _method,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: _methodColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayUrl, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (uri?.query.isNotEmpty == true)
                    Text(
                      '?${uri!.query}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                if (elapsed.isNotEmpty) Text(elapsed, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkDetailSheet extends StatelessWidget {
  const _NetworkDetailSheet({required this.entry});
  final NetworkLogEntry entry;

  String _toCurl() {
    final buf = StringBuffer('curl -X ${entry.method}');
    for (final h in entry.requestHeaders.entries) {
      buf.write(" \\\n  -H '${h.key}: ${h.value}'");
    }
    if (entry.requestBody != null && entry.requestBody!.isNotEmpty) {
      buf.write(" \\\n  -d '${entry.requestBody}'");
    }
    buf.write(" \\\n  '${entry.url}'");
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Request Detail', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.terminal, size: 14),
                    label: const Text('Copy cURL', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _toCurl()));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('cURL copied'), duration: Duration(seconds: 1)));
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionHeader('Request'),
                  _KVRow('Method', entry.method),
                  _KVRow('URL', entry.url),
                  _KVRow('Time', entry.timestamp.toIso8601String()),
                  if (entry.elapsedMs != null) _KVRow('Elapsed', '${entry.elapsedMs}ms'),
                  if (entry.requestHeaders.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const _SectionHeader('Request Headers'),
                    for (final h in entry.requestHeaders.entries) _KVRow(h.key, h.value),
                  ],
                  if (entry.requestBody != null && entry.requestBody!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _CodeBlock(title: 'Request Body', content: entry.requestBody!),
                  ],
                  if (entry.statusCode != null) ...[
                    const SizedBox(height: 10),
                    const _SectionHeader('Response'),
                    _KVRow('Status', '${entry.statusCode}'),
                    if (entry.responseHeaders != null)
                      for (final h in entry.responseHeaders!.entries) _KVRow(h.key, h.value),
                  ],
                  if (entry.responseBody != null && entry.responseBody!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _CodeBlock(title: 'Response Body', content: entry.responseBody!),
                  ],
                  if (entry.error != null) ...[
                    const SizedBox(height: 10),
                    _CodeBlock(title: 'Error', content: entry.error!, isError: true),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  const _KVRow(this.key_, this.value);
  final String key_;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(key_, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.title, required this.content, this.isError = false});
  final String title;
  final String content;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionHeader(title),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 12),
              label: const Text('Copy', style: TextStyle(fontSize: 11)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
              },
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isError ? Colors.red.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: (isError ? Colors.red : Colors.grey).withValues(alpha: 0.2)),
          ),
          child: SelectableText(
            content,
            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: isError ? Colors.red.shade300 : null),
          ),
        ),
      ],
    );
  }
}
