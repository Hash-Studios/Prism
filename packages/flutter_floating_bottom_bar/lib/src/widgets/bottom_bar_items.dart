import 'package:flutter/widgets.dart';

import '../internal/bottom_bar_item_height.dart';

/// Controls when a [BottomBarItem]'s label is visible when it is placed
/// inside a [BottomBarItems] row.
enum BottomBarLabelBehavior {
  /// Always show the label, regardless of selection state.
  alwaysShow,

  /// Only show the label on the selected item.
  onlySelected,

  /// Never show the label.
  alwaysHide,
}

/// A thin row layout helper for [BottomBarItem]s (or any other widgets).
///
/// Arranges [children] horizontally with [spacing] as the main-axis alignment.
/// In bounded rows wide enough for each child's 48px minimum target, each
/// child is wrapped in [Expanded] so all items share the available width
/// equally. Narrow bounded rows use a horizontal [SingleChildScrollView] to
/// preserve those targets. Unbounded rows keep their raw children. Designed
/// to be passed as [BottomBar.child]:
///
/// ```dart
/// BottomBar(
///   child: BottomBarItems(
///     children: [
///       BottomBarItem(icon: Icon(Icons.home), selected: true, onTap: () {}),
///       BottomBarItem(icon: Icon(Icons.search), onTap: () {}),
///     ],
///   ),
///   body: ...,
/// )
/// ```
class BottomBarItems extends StatelessWidget {
  /// Creates a [BottomBarItems] row.
  const BottomBarItems({
    super.key,
    required this.children,
    this.spacing = MainAxisAlignment.spaceAround,
    this.labelBehavior = BottomBarLabelBehavior.alwaysShow,
  });

  /// The widgets to display in the row — typically [BottomBarItem] instances.
  final List<Widget> children;

  /// Main-axis alignment applied to the [Row].
  ///
  /// Defaults to [MainAxisAlignment.spaceAround]. In wide bounded rows, this
  /// only affects layout when [children] is empty because each child is
  /// expanded.
  final MainAxisAlignment spacing;

  /// Controls when descendant [BottomBarItem] labels are visible.
  ///
  /// Exposed to descendants via [BottomBarItemsScope]. Defaults to
  /// [BottomBarLabelBehavior.alwaysShow].
  final BottomBarLabelBehavior labelBehavior;

  @override
  Widget build(BuildContext context) {
    return BottomBarItemsScope(
      labelBehavior: labelBehavior,
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget withItemHeight(Widget child) => BottomBarItemHeightScope(
            minHeight: constraints.hasTightHeight && constraints.maxHeight > 48
                ? constraints.maxHeight
                : 48,
            child: child,
          );

          Widget row(List<Widget> rowChildren) => Row(
            mainAxisAlignment: spacing,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: rowChildren,
          );

          if (!constraints.hasBoundedWidth) {
            return withItemHeight(row(children));
          }
          if (constraints.maxWidth < children.length * 48) {
            return withItemHeight(
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: row(children),
              ),
            );
          }
          return withItemHeight(
            row([for (final child in children) Expanded(child: child)]),
          );
        },
      ),
    );
  }
}

/// Exposes the enclosing [BottomBarItems.labelBehavior] to descendant
/// [BottomBarItem]s.
///
/// [BottomBarItem] reads this via [BottomBarItemsScope.maybeOf] to decide
/// whether to render its label. An item used outside a [BottomBarItems] row
/// falls back to [BottomBarLabelBehavior.alwaysShow].
class BottomBarItemsScope extends InheritedWidget {
  /// Creates a [BottomBarItemsScope].
  const BottomBarItemsScope({
    super.key,
    required this.labelBehavior,
    required super.child,
  });

  /// The label behavior in effect for descendant [BottomBarItem]s.
  final BottomBarLabelBehavior labelBehavior;

  /// Returns the nearest enclosing [BottomBarItemsScope]'s [labelBehavior],
  /// or `null` if there isn't one.
  static BottomBarLabelBehavior? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BottomBarItemsScope>()
        ?.labelBehavior;
  }

  @override
  bool updateShouldNotify(BottomBarItemsScope oldWidget) {
    return labelBehavior != oldWidget.labelBehavior;
  }
}
