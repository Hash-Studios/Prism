import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
double screenSideSafeColumnWidth(BuildContext context) =>
    _sideColumn(MediaQueryData.fromView(View.of(context)).viewPadding);

double _sideColumn(EdgeInsets viewPadding) {
  return _isSideColumn(viewPadding) ? viewPadding.right : 0;
}

bool _isSideColumn(EdgeInsets nativeViewPadding) =>
    defaultTargetPlatform == TargetPlatform.iOS &&
    nativeViewPadding.top == 0 &&
    nativeViewPadding.left == 0 &&
    nativeViewPadding.right > 0;
