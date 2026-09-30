import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/material.dart';

/// A modal bottom sheet with the app's shared open and close animation.
Future<T?> showPrismSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool showDragHandle = false,
  bool useRootNavigator = false,
}) {
  final bool reduce = context.reduceMotion;
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor,
    shape: shape,
    showDragHandle: showDragHandle,
    useRootNavigator: useRootNavigator,
    sheetAnimationStyle: AnimationStyle(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
      reverseDuration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      curve: PrismCurves.enter,
      reverseCurve: PrismCurves.exit,
    ),
  );
}
