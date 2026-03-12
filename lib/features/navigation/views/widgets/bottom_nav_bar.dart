import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart' as floating;

class BottomBar extends StatefulWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  late final floating.BottomBarController _bottomBarController;

  @override
  void initState() {
    super.initState();
    _bottomBarController = floating.BottomBarController();
  }

  @override
  Widget build(BuildContext context) {
    return floating.BottomBar(
      hideOnScroll: false,
      controller: _bottomBarController,
      iconTooltip: 'Scroll to top',
      iconDecoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle),
      barDecoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(500)),
      child: const PrismBottomNav(),
      body: (context, _) =>
          _BottomBarScrollVisibility(controller: _bottomBarController, child: widget.child ?? const SizedBox.shrink()),
    );
  }
}

class _BottomBarScrollVisibility extends StatefulWidget {
  final floating.BottomBarController controller;
  final Widget child;

  const _BottomBarScrollVisibility({required this.controller, required this.child});

  @override
  State<_BottomBarScrollVisibility> createState() => _BottomBarScrollVisibilityState();
}

class _BottomBarScrollVisibilityState extends State<_BottomBarScrollVisibility> {
  ScrollDirection _lastDirection = ScrollDirection.idle;

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final direction = notification.direction;
    if (direction == ScrollDirection.idle || direction == _lastDirection) {
      return false;
    }

    _lastDirection = direction;
    if (direction == ScrollDirection.reverse) {
      widget.controller.hide();
    } else if (direction == ScrollDirection.forward) {
      widget.controller.show();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(onNotification: _onUserScroll, child: widget.child);
  }
}
