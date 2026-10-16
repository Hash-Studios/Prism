import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/features/navigation/views/widgets/nav_bar_surface.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart' as floating;

/// Hosts the tab content with the floating pill and create button above it. The bar hides while the user scrolls
/// down; a back-to-top button takes its place.
class BottomBar extends StatefulWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  final floating.BottomBarController _controller = floating.BottomBarController();
  final ValueNotifier<bool> _barVisible = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _barVisible.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return floating.BottomBar(
      controller: _controller,
      layout: floating.BottomBarLayout(width: MediaQuery.sizeOf(context).width, fit: StackFit.expand),
      theme: const floating.BottomBarThemeData(barDecoration: BoxDecoration()),
      showIcon: false,
      onVisibilityChanged: (bool visible) => _barVisible.value = visible,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child ?? const SizedBox.shrink(),
          _BackToTop(visible: _barVisible, onPressed: _controller.scrollToStart),
        ],
      ),
      child: const Align(
        heightFactor: 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IntrinsicWidth(child: PrismBottomNav()),
            SizedBox(width: 12),
            PrismFab(),
          ],
        ),
      ),
    );
  }
}

/// Sits where the bar sits while the bar is hidden. Fades and scales in from 0.9.
class _BackToTop extends StatelessWidget {
  const _BackToTop({required this.visible, required this.onPressed});

  final ValueListenable<bool> visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 60,
            child: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (BuildContext context, bool barVisible, Widget? child) => IgnorePointer(
                  ignoring: barVisible,
                  child: ExcludeSemantics(
                    excluding: barVisible,
                    child: AnimatedOpacity(
                      opacity: barVisible ? 0 : 1,
                      duration: context.motion(PrismDurations.fast),
                      curve: PrismCurves.enter,
                      child: AnimatedScale(
                        scale: barVisible ? 0.9 : 1,
                        duration: context.motion(PrismDurations.fast),
                        curve: PrismCurves.enter,
                        child: child,
                      ),
                    ),
                  ),
                ),
                child: DecoratedBox(
                  decoration: navBarDecoration(context, circle: true),
                  child: PrismIconButton(
                    icon: Icons.arrow_upward_rounded,
                    tooltip: 'Back to top',
                    onPressed: onPressed,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
