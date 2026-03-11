import 'package:Prism/core/widgets/focussedMenu/focused_menu_data.dart';
import 'package:Prism/core/widgets/focussedMenu/focused_menu_overlay.dart';
import 'package:flutter/material.dart';

class FocusedMenuDetails extends StatelessWidget {
  const FocusedMenuDetails({
    super.key,
    required this.provider,
    required this.childOffset,
    required this.childSize,
    required this.child,
    required this.index,
    required this.size,
    required this.orientation,
  });

  final String? provider;
  final Offset childOffset;
  final Size? childSize;
  final int index;
  final Size size;
  final Orientation orientation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = FocusedMenuDataAdapter.fromLegacy(context, provider: provider, index: index);
    if (data == null || childSize == null) {
      return const SizedBox.shrink();
    }
    return FocusedMenuOverlay(menuData: data, childOffset: childOffset, childSize: childSize!, child: child);
  }
}
