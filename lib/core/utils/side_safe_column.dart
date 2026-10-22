import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Carries side-column width changes through nested media queries that remove the rail's right padding.
class SideSafeColumnScope extends InheritedWidget {
  const SideSafeColumnScope({required this.nativeWidth, required super.child, super.key});

  final double nativeWidth;

  @override
  bool updateShouldNotify(SideSafeColumnScope oldWidget) => nativeWidth != oldWidget.nativeWidth;
}

/// Width of the iOS right-column signature, or 0 when there is none. The native view must have a right inset and no
/// top or left inset. The scoped view padding determines the width, so removing the right padding from nested content
/// still returns 0.
double sideSafeColumnWidth(BuildContext context) {
  final EdgeInsets scopedViewPadding = MediaQuery.viewPaddingOf(context);
  final EdgeInsets nativeViewPadding = MediaQueryData.fromView(View.of(context)).viewPadding;
  if (!_isSideColumn(nativeViewPadding)) return 0;
  return _sideColumn(scopedViewPadding);
}

/// [sideSafeColumnWidth] for the whole screen. It also works under the tab bar's side rail, which removes the right
/// padding from the tab content.
double screenSideSafeColumnWidth(BuildContext context) {
  MediaQuery.viewPaddingOf(context);
  context.dependOnInheritedWidgetOfExactType<SideSafeColumnScope>();
  return _sideColumn(MediaQueryData.fromView(View.of(context)).viewPadding);
}

double _sideColumn(EdgeInsets viewPadding) {
  return _isSideColumn(viewPadding) ? viewPadding.right : 0;
}

bool _isSideColumn(EdgeInsets nativeViewPadding) =>
    defaultTargetPlatform == TargetPlatform.iOS &&
    nativeViewPadding.top == 0 &&
    nativeViewPadding.left == 0 &&
    nativeViewPadding.right > 0;
