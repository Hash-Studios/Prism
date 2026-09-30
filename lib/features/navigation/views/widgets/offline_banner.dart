import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/material.dart';

class ConnectivityWidget extends StatefulWidget {
  const ConnectivityWidget({super.key});

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
      alignment: Alignment.bottomCenter,
      child: SlideTransition(position: _position, child: const _OfflineBanner()),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      width: double.infinity,
      color: Colors.red,
      child: const Text(
        "No Internet",
        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Proxima Nova'),
        textAlign: TextAlign.center,
      ),
    );
  }
}
