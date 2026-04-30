import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
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
      showIcon: false,
      iconTooltip: 'Scroll to top',
      layout: floating.BottomBarLayout(
        width: MediaQuery.of(context).size.width,
        borderRadius: BorderRadius.circular(500),
      ),
      scrollBehavior: const floating.BottomBarScrollBehavior(
        hideOnScroll: false,
      ),
      theme: floating.BottomBarThemeData(
        barDecoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(500),
        ),
      ),
      controller: _bottomBarController,
      body: _BottomBarScrollVisibility(
        controller: _bottomBarController,
        child: widget.child ?? const SizedBox.shrink(),
      ),
      child: const Align(
        heightFactor: 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicWidth(child: PrismBottomNav()),
            SizedBox(width: 12),
            PrismFab(),
          ],
        ),
      ),
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
  bool _onUserScroll(UserScrollNotification notification) {
    if (!mounted || notification.metrics.axis != Axis.vertical) return false;
    if (notification.direction == ScrollDirection.reverse) {
      widget.controller.hide();
    } else if (notification.direction == ScrollDirection.forward) {
      widget.controller.show();
    }
    return false;
  }

  Future<void> _scrollToTop() async {
    await widget.controller.scrollToStart();
    widget.controller.show();
  }

  Widget _buildScrollToTopButton(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final bool showButton = !widget.controller.isVisible;
        return IgnorePointer(
          ignoring: !showButton,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: showButton ? 1 : 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _scrollToTop,
                          child: const Icon(JamIcons.arrow_up, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: _onUserScroll,
      child: Stack(fit: StackFit.expand, children: <Widget>[widget.child, _buildScrollToTopButton(context)]),
    );
  }
}
