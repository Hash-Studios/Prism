import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A slim "You are offline" pill that slides down under the top bar after a second and leaves after ten.
class ConnectivityWidget extends StatefulWidget {
  const ConnectivityWidget({super.key});

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
  late final Timer _showTimer;
  late final Timer _hideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _showTimer = Timer(const Duration(seconds: 1), () => _move(true));
    _hideTimer = Timer(const Duration(seconds: 10), () => _move(false));
  }

  void _move(bool show) {
    if (!mounted) return;
    _visible = show;
    if (context.reduceMotion) {
      _controller.value = show ? 1 : 0;
    } else {
      show ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) _controller.value = _visible ? 1 : 0;
  }

  @override
  void dispose() {
    _showTimer.cancel();
    _hideTimer.cancel();
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
            child: SlideTransition(position: _position, child: const _OfflinePill()),
          ),
        ),
      ),
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.wifi_off_rounded, size: 16, color: cs.onSurface),
              const SizedBox(width: PrismSpace.xs),
              Text('You are offline', style: PrismTextStyles.rowTitle(context)),
            ],
          ),
        ),
      ),
    );
  }
}
