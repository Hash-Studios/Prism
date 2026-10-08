import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/material.dart';

const Duration _backOnlineDuration = Duration(seconds: 2);

class ConnectivityWidget extends StatefulWidget {
  const ConnectivityWidget({required this.offline, super.key});

  final bool offline;

  @override
  _ConnectivityWidgetState createState() => _ConnectivityWidgetState();
}

class _ConnectivityWidgetState extends State<ConnectivityWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 180),
    vsync: this,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: PrismCurves.enter,
    reverseCurve: PrismCurves.exit,
  );
  late final Animation<Offset> _position = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(_curve);
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
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: _position,
        child: ExcludeSemantics(
          excluding: !_shown,
          child: _OfflineBanner(online: _backOnline),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String message = online ? 'Back online' : 'No internet connection';
    final Color background = online ? scheme.inverseSurface : scheme.errorContainer;
    final Color foreground = online ? scheme.onInverseSurface : scheme.onErrorContainer;
    return Semantics(
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        width: double.infinity,
        color: background,
        child: Text(
          message,
          style: TextStyle(fontSize: 12, color: foreground, fontWeight: FontWeight.bold, fontFamily: 'Proxima Nova'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
