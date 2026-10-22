import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Width of the safe column that iOS keeps on the right of a portrait screen, or 0 when there is none. Only the iPhone
/// Duo outer screen has one: it shows the camera and the status bar there. Other iPhones, iPads and Android get 0.
double sideSafeColumnWidth(BuildContext context) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return 0;
  if (MediaQuery.orientationOf(context) != Orientation.portrait) return 0;
  return MediaQuery.viewPaddingOf(context).right;
}
