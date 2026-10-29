import 'package:flutter/widgets.dart';

import '../bottom_bar_scope.dart';

/// Adds bottom padding equal to the current [BottomBar] footprint.
///
/// Use inside [BottomBar.body] to keep content clear of the floating bar while
/// still layering the bar above the scrollable. The reserved space stays in
/// place while the bar is hidden because [BottomBarScope.barHeight] reports the
/// bar's layout footprint, not its animated transform. That footprint includes
/// the measured bar height plus [BottomBarLayout.offset] and bottom safe-area
/// when enabled.
///
/// This widget is intentionally bottom-edge clearance for bottom-aligned bars.
/// It does not inspect [BottomBarLayout.alignment] or try to reserve space on
/// any other edge.
class BottomBarBodyPadding extends StatelessWidget {
  const BottomBarBodyPadding({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Extra padding applied in addition to the reserved bar footprint.
  final EdgeInsetsGeometry padding;

  /// Descendant content that should be inset away from the bar.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final barHeight = BottomBarScope.of(context).barHeight;

    return ValueListenableBuilder<double>(
      valueListenable: barHeight,
      builder: (context, value, child) {
        final resolved = padding.resolve(Directionality.of(context));
        return Padding(
          padding: EdgeInsets.fromLTRB(
            resolved.left,
            resolved.top,
            resolved.right,
            resolved.bottom + value,
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}
