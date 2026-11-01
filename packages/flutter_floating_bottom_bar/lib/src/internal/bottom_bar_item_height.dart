import 'package:flutter/widgets.dart';

/// Internal layout constraints shared with descendant [BottomBarItem]s.
class BottomBarItemHeightScope extends InheritedWidget {
  /// Creates an item-height scope.
  const BottomBarItemHeightScope({
    super.key,
    required this.minHeight,
    required super.child,
  });

  /// Minimum height available to a descendant item.
  final double minHeight;

  /// Returns the nearest item-height scope value, if present.
  static double? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BottomBarItemHeightScope>()
        ?.minHeight;
  }

  @override
  bool updateShouldNotify(BottomBarItemHeightScope oldWidget) {
    return minHeight != oldWidget.minHeight;
  }
}
