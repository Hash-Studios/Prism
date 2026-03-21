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
      hideOnScroll: false,
      showIcon: false,
      width: MediaQuery.of(context).size.width,
      barColor: Colors.transparent,
      borderRadius: BorderRadius.circular(500),
      controller: _bottomBarController,
      iconTooltip: 'Scroll to top',
      iconDecoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
      icon: (width, height) => Icon(JamIcons.arrow_up, color: Colors.white, size: width),
      iconWidth: 32,
      iconHeight: 32,
      barDecoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(500)),
      child: const Align(
        heightFactor: 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IntrinsicWidth(child: PrismBottomNav()),
            SizedBox(width: 12),
            PrismFab(),
          ],
        ),
      ),
      body: (context, scrollController) => _BottomBarScrollVisibility(
        controller: _bottomBarController,
        scrollController: scrollController,
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _BottomBarScrollVisibility extends StatefulWidget {
  final floating.BottomBarController controller;
  final ScrollController scrollController;
  final Widget child;

  const _BottomBarScrollVisibility({required this.controller, required this.scrollController, required this.child});

  @override
  State<_BottomBarScrollVisibility> createState() => _BottomBarScrollVisibilityState();
}

class _BottomBarScrollVisibilityState extends State<_BottomBarScrollVisibility> {
  ScrollPosition? _activeScrollPosition;

  void _resolveActiveScrollPosition() {
    if (!mounted) {
      return;
    }

    if (widget.scrollController.hasClients) {
      _activeScrollPosition = widget.scrollController.position;
      return;
    }

    final ScrollController? primaryController = PrimaryScrollController.maybeOf(context);
    if (primaryController != null && primaryController.positions.length == 1) {
      _activeScrollPosition = primaryController.position;
      return;
    }

    final ScrollableState? localScrollable = Scrollable.maybeOf(context);
    if (localScrollable != null) {
      _activeScrollPosition = localScrollable.position;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveActiveScrollPosition();
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (!mounted || notification.metrics.axis != Axis.vertical) return false;
    _resolveActiveScrollPosition();
    if (notification.direction == ScrollDirection.reverse) {
      widget.controller.hide();
    } else if (notification.direction == ScrollDirection.forward) {
      widget.controller.show();
    }
    return false;
  }

  Future<void> _scrollToTop() async {
    _resolveActiveScrollPosition();
    final ScrollPosition? position = _activeScrollPosition;
    if (position == null) {
      return;
    }

    await position.animateTo(
      position.minScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
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
            curve: Curves.linear,
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
