import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A slim pill that slides down under the top bar after a second while offline, says "Back online" for two seconds
/// on recovery, then leaves.
const Duration _backOnlineDuration = Duration(seconds: 2);

class ConnectivityWidget extends StatefulWidget {
  const ConnectivityWidget({required this.offline, super.key});

  final bool offline;

  @override
  _ConnectivityWidgetState createState() => _ConnectivityWidgetState();
}

class _ConnectivityWidgetState extends State<ConnectivityWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: PrismDurations.base,
    reverseDuration: PrismDurations.fast,
    vsync: this,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: PrismCurves.enter,
    reverseCurve: PrismCurves.exit,
  );
  late final Animation<Offset> _position = Tween<Offset>(
    begin: const Offset(0, -1.5),
    end: Offset.zero,
  ).animate(_curve);
  Timer? _showTimer;
  Timer? _backOnlineTimer;
  bool _shown = false;
  bool _backOnline = false;

  @override
  void initState() {
    super.initState();
    if (widget.offline) {
      _showTimer = Timer(const Duration(seconds: 1), () => _move(true));
    }
  }

  @override
  void didUpdateWidget(ConnectivityWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offline == widget.offline) return;
    _showTimer?.cancel();
    _backOnlineTimer?.cancel();
    if (!widget.offline && _shown) {
      _backOnline = true;
      _backOnlineTimer = Timer(_backOnlineDuration, () {
        if (!mounted) return;
        setState(() => _backOnline = false);
        _move(false);
      });
      return;
    }
    _backOnline = false;
    _move(widget.offline);
  }

  void _move(bool show) {
    if (!mounted) return;
    setState(() => _shown = show);
    if (context.reduceMotion) {
      _controller.value = show ? 1 : 0;
    } else {
      show ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion && _showTimer?.isActive != true && _backOnlineTimer?.isActive != true) {
      _controller.value = widget.offline ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _backOnlineTimer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: PrismSpace.xs),
        child: IgnorePointer(
          child: FadeTransition(
            opacity: _curve,
            child: SlideTransition(
              position: _position,
              child: ExcludeSemantics(
                excluding: !_shown,
                child: _OfflinePill(online: _backOnline),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String message = online ? context.l10n.navigationBackOnline : context.l10n.navigationNoInternetConnection;
    final Color background = online ? cs.inverseSurface : cs.surfaceContainerHigh;
    final Color foreground = online ? cs.onInverseSurface : cs.onSurface;
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(online ? Icons.wifi_rounded : Icons.wifi_off_rounded, size: 16, color: foreground),
              const SizedBox(width: PrismSpace.xs),
              Text(message, style: PrismTextStyles.rowTitle(context).copyWith(color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}
