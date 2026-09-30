import 'dart:async';

import 'package:flutter/material.dart';

class ConnectivityWidget extends StatefulWidget {
  const ConnectivityWidget({super.key});

  @override
  _ConnectivityWidgetState createState() => _ConnectivityWidgetState();
}

class _ConnectivityWidgetState extends State<ConnectivityWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );
  late final Timer _showTimer;
  late final Timer _hideTimer;

  @override
  void initState() {
    super.initState();
    _showTimer = Timer(const Duration(seconds: 1), _controller.forward);
    _hideTimer = Timer(const Duration(seconds: 10), _controller.reverse);
  }

  @override
  void dispose() {
    _showTimer.cancel();
    _hideTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: _controller.drive(
          Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.fastOutSlowIn)),
        ),
        child: const _OfflineBanner(),
      ),
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
