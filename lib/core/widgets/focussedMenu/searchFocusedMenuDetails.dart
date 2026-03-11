import 'package:Prism/core/widgets/focussedMenu/focused_menu_data.dart';
import 'package:Prism/core/widgets/focussedMenu/focused_menu_overlay.dart';
import 'package:flutter/material.dart';

class SearchFocusedMenuDetails extends StatelessWidget {
  const SearchFocusedMenuDetails({
    super.key,
    required this.selectedProvider,
    required this.query,
    required this.childOffset,
    required this.childSize,
    required this.child,
    required this.index,
  });

  final String? selectedProvider;
  final String query;
  final Offset childOffset;
  final Size? childSize;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = FocusedMenuDataAdapter.fromSearch(provider: selectedProvider, index: index);
    if (data == null || childSize == null) {
      return const SizedBox.shrink();
    }
    return FocusedMenuOverlay(menuData: data, childOffset: childOffset, childSize: childSize!, child: child);
  }
}
