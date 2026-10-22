import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Width of the safe column that iOS keeps on the right of the screen, or 0 when there is none. Only the iPhone Duo
/// has one, on the outer screen and on the inner screen in landscape: it shows the camera and the status bar there, so
/// there is no top inset. Other iPhones have no side inset in portrait and one on both sides in landscape. iPads and
/// Android get 0.
double sideSafeColumnWidth(BuildContext context) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return 0;
  final EdgeInsets viewPadding = MediaQuery.viewPaddingOf(context);
  return viewPadding.top == 0 && viewPadding.left == 0 ? viewPadding.right : 0;
}
