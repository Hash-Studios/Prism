import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Width of the reported iOS side-column signature, or 0 when the current view does not match it.
///
/// The reported outer-screen signature has an 84 logical-pixel right inset and no top inset. Native view and display
/// metrics keep resized MediaQuery windows from making an iPad or landscape view appear to match.
double sideSafeColumnWidth(BuildContext context) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return 0;
  if (MediaQuery.orientationOf(context) != Orientation.portrait) return 0;

  final view = View.of(context);
  final Size nativeViewSize = view.physicalSize / view.devicePixelRatio;
  final Size nativeDisplaySize = view.display.size / view.display.devicePixelRatio;
  if (nativeViewSize.width >= nativeViewSize.height || nativeDisplaySize.shortestSide >= 600) return 0;

  final EdgeInsets nativeViewPadding = MediaQueryData.fromView(view).viewPadding;
  final EdgeInsets scopedViewPadding = MediaQuery.viewPaddingOf(context);
  if (nativeViewPadding.top != 0 || nativeViewPadding.right != 84) return 0;
  if (scopedViewPadding.top != nativeViewPadding.top || scopedViewPadding.right != nativeViewPadding.right) return 0;

  return nativeViewPadding.right;
}
