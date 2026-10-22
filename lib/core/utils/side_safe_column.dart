import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Width of the safe column that iOS keeps on the right of the screen, or 0 when there is none. Only the iPhone Duo
/// has one, on the outer screen and on the inner screen in landscape: it shows the camera and the status bar there, so
/// there is no top inset. Other iPhones have no side inset in portrait and one on both sides in landscape. iPads and
/// Android get 0.
double sideSafeColumnWidth(BuildContext context) => _sideColumn(MediaQuery.viewPaddingOf(context));

/// [sideSafeColumnWidth] for the whole screen. It also works under the tab bar's side rail, which removes the right
/// padding from the tab content.
double screenSideSafeColumnWidth(BuildContext context) =>
    _sideColumn(MediaQueryData.fromView(View.of(context)).viewPadding);

double _sideColumn(EdgeInsets viewPadding) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return 0;
  return viewPadding.top == 0 && viewPadding.left == 0 ? viewPadding.right : 0;
}
