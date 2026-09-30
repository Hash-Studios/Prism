import 'dart:async';

import 'package:Prism/core/debug/debug_flags.dart';
import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Only show toasts for warn-level and above by default to avoid flooding
/// the overlay with trace/debug messages from BLoC observer etc.
const AppLogLevel _kToastMinLevel = AppLogLevel.warn;

/// Maximum number of toasts visible simultaneously.
const int _kMaxToasts = 5;

/// The colour of each log level. These are data colours, so they do not follow the theme. Every debug surface reads
/// them from here.
extension AppLogLevelColor on AppLogLevel {
  Color get color => switch (this) {
    AppLogLevel.debug => const Color(0xFF78909C),
    AppLogLevel.info => PrismColors.success,
    AppLogLevel.warn => PrismColors.warning,
    AppLogLevel.error => const Color(0xFFE5484D),
  };
}

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
              left: PrismSpace.sm,
              right: PrismSpace.sm,
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

/// One log line as a toast. It sits above the app's theme, so it uses the inverse surface of whichever theme is
/// found and marks the level with a coloured chip.
class _LogToastWidget extends StatelessWidget {
  const _LogToastWidget({super.key, required this.entry});
  final _ToastEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color level = entry.record.level.color;
    final String label = entry.record.level.shortLabel;
    final String? tag = entry.record.tag;
    final TextStyle base = PrismTextStyles.caption(
      context,
    ).copyWith(fontWeight: FontWeight.w600, color: cs.onInverseSurface);

    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpace.xxs),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xs),
          decoration: BoxDecoration(color: cs.inverseSurface, borderRadius: BorderRadius.circular(PrismRadius.sm)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: level, borderRadius: BorderRadius.circular(PrismRadius.pill)),
                child: Text(
                  label,
                  style: base.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black),
                ),
              ),
              const SizedBox(width: PrismSpace.xs),
              if (tag != null) ...[
                Text('[$tag]', style: base.copyWith(color: cs.onInverseSurface.withValues(alpha: 0.7))),
                const SizedBox(width: PrismSpace.xxs),
              ],
              Expanded(
                child: Text(entry.record.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: base),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
