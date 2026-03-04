import 'dart:async';

import 'package:Prism/core/debug/debug_flags.dart';
import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:flutter/material.dart';

/// Only show toasts for warn-level and above by default to avoid flooding
/// the overlay with trace/debug messages from BLoC observer etc.
const AppLogLevel _kToastMinLevel = AppLogLevel.warn;

/// Maximum number of toasts visible simultaneously.
const int _kMaxToasts = 5;

/// Wraps the app and injects log toast overlays when [DebugFlags.showLogToasts]
/// is enabled. Toasts appear at the bottom of the screen and auto-dismiss
/// after 3 seconds.
class LogToastOverlay extends StatefulWidget {
  const LogToastOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<LogToastOverlay> createState() => _LogToastOverlayState();
}

class _LogToastOverlayState extends State<LogToastOverlay> {
  StreamSubscription<AppLogRecord>? _sub;
  final List<_ToastEntry> _toasts = [];

  @override
  void initState() {
    super.initState();
    _sub = InMemoryLogSink.instance.stream.listen(_onRecord);
  }

  void _onRecord(AppLogRecord record) {
    if (!DebugFlags.instance.showLogToasts) return;
    // Only surface warn/error/fatal to avoid flooding with BLoC trace/debug.
    if (record.level.index < _kToastMinLevel.index) return;
    if (!mounted) return;

    final entry = _ToastEntry(record: record, id: UniqueKey());

    // Defer setState to the next frame so we never trigger a rebuild
    // synchronously during an active gesture dispatch (which would invalidate
    // _CupertinoBackGestureDetector's internal controller and cause an assertion).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        // Cap simultaneous toasts to avoid memory/render pressure.
        if (_toasts.length >= _kMaxToasts) {
          _toasts.removeAt(0);
        }
        _toasts.add(entry);
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _toasts.remove(entry));
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_toasts.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 12,
              right: 12,
              // IgnorePointer ensures toast widgets never absorb edge-swipe
              // gestures that belong to the Cupertino back-swipe detector.
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _toasts.map((e) => _LogToastWidget(key: e.id, entry: e)).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToastEntry {
  _ToastEntry({required this.record, required this.id});
  final AppLogRecord record;
  final Key id;
}

class _LogToastWidget extends StatelessWidget {
  const _LogToastWidget({super.key, required this.entry});
  final _ToastEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(entry.record.level);
    final label = entry.record.level.shortLabel;
    final tag = entry.record.tag;
    final message = entry.record.message;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              if (tag != null) ...[
                Text('[$tag]', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _levelColor(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.trace:
        return Colors.grey.shade700;
      case AppLogLevel.debug:
        return Colors.blueGrey.shade600;
      case AppLogLevel.info:
        return Colors.green.shade700;
      case AppLogLevel.warn:
        return Colors.orange.shade700;
      case AppLogLevel.error:
        return Colors.red.shade700;
      case AppLogLevel.fatal:
        return Colors.purple.shade800;
    }
  }
}
