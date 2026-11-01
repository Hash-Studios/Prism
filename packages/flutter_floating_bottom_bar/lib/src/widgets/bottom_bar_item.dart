import 'package:material_ui/material_ui.dart';

import '../internal/bottom_bar_item_height.dart';
import 'bottom_bar_items.dart';

/// A simple, opinionated nav-item widget for use inside [BottomBar.child].
///
/// Renders an [icon] (or [selectedIcon] when [selected]), an optional [label]
/// underneath, and an optional [badge] floating on the icon's top-end.
/// Wraps the whole thing in an [InkWell] with an explicit 48 by 48 minimum
/// interactive target, button semantics, and an optional [Tooltip].
///
/// Use [semanticLabel] to provide a deterministic accessible name when the
/// visible [label] is decorative, custom, or otherwise unsuitable for
/// accessibility. When [semanticLabel] is null, [tooltip] becomes the explicit
/// accessible name fallback. If neither is provided, the child's own semantics
/// remain visible.
///
/// No internal selection state — pass [selected] from your own state and
/// handle [onTap].
class BottomBarItem extends StatelessWidget {
  const BottomBarItem({
    super.key,
    required this.icon,
    this.selectedIcon,
    this.label,
    this.badge,
    this.selected = false,
    this.onTap,
    this.semanticLabel,
    this.tooltip,
    this.color,
    this.selectedColor,
  });

  /// The icon displayed when [selected] is `false`.
  final Widget icon;

  /// The icon displayed when [selected] is `true`.
  ///
  /// Falls back to [icon] when null.
  final Widget? selectedIcon;

  /// Optional label rendered below the icon.
  ///
  /// Styled with `textTheme.labelSmall` tinted to [color] or [selectedColor].
  /// A `Text` label with non-null `data` is truncated to a single line with
  /// an ellipsis. Other widgets (including `Text.rich`) are left untouched.
  /// Label visibility is controlled by the enclosing
  /// [BottomBarItems.labelBehavior].
  final Widget? label;

  /// Optional badge rendered in the top-end corner of the icon.
  ///
  /// Typically a [Badge] widget. Use for notification counts or dot indicators.
  final Widget? badge;

  /// Whether this item is currently the active/selected tab.
  ///
  /// Does not maintain state internally — pass from your own state and update
  /// in [onTap].
  final bool selected;

  /// Called when the item is tapped.
  final VoidCallback? onTap;

  /// Explicit accessible name for this item.
  ///
  /// When non-null, this name is exposed as the only semantics label for the
  /// item and descendant semantics are excluded to prevent duplicate
  /// announcements. When null, [tooltip] becomes the explicit accessible name
  /// fallback. If both are null, descendant semantics remain visible.
  final String? semanticLabel;

  /// Tooltip shown on long-press.
  ///
  /// When [semanticLabel] is null, this also becomes the explicit accessible
  /// name fallback. When null no tooltip is rendered.
  final String? tooltip;

  /// Icon and label colour when [selected] is `false`.
  ///
  /// Defaults to `colorScheme.onSurfaceVariant`.
  final Color? color;

  /// Icon and label colour when [selected] is `true`.
  ///
  /// Defaults to `colorScheme.primary`.
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelBehavior =
        BottomBarItemsScope.maybeOf(context) ??
        BottomBarLabelBehavior.alwaysShow;
    final showLabel = switch (labelBehavior) {
      BottomBarLabelBehavior.alwaysShow => true,
      BottomBarLabelBehavior.onlySelected => selected,
      BottomBarLabelBehavior.alwaysHide => false,
    };
    final effectiveColor = selected
        ? (selectedColor ?? cs.primary)
        : (color ?? cs.onSurfaceVariant);
    final explicitSemanticLabel = semanticLabel ?? tooltip;
    final minHeight = BottomBarItemHeightScope.maybeOf(context) ?? 48;

    final iconWidget = selected ? (selectedIcon ?? icon) : icon;

    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        IconTheme.merge(
          data: IconThemeData(color: effectiveColor),
          child: iconWidget,
        ),
        if (badge != null)
          PositionedDirectional(top: -4, end: -4, child: badge!),
      ],
    );

    final currentLabel = label;
    Widget labelChild = currentLabel ?? const SizedBox.shrink();
    if (currentLabel is Text && currentLabel.data != null) {
      labelChild = Text(
        currentLabel.data!,
        key: currentLabel.key,
        style: currentLabel.style,
        strutStyle: currentLabel.strutStyle,
        textAlign: currentLabel.textAlign ?? TextAlign.center,
        textDirection: currentLabel.textDirection,
        locale: currentLabel.locale,
        softWrap: currentLabel.softWrap,
        textScaler: currentLabel.textScaler,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        semanticsLabel: currentLabel.semanticsLabel,
        semanticsIdentifier: currentLabel.semanticsIdentifier,
        textWidthBasis: currentLabel.textWidthBasis,
        textHeightBehavior: currentLabel.textHeightBehavior,
        selectionColor: currentLabel.selectionColor,
      );
    }

    final accessibleLabel =
        explicitSemanticLabel ??
        (!showLabel && currentLabel is Text && currentLabel.data != null
            ? currentLabel.semanticsLabel ?? currentLabel.data
            : null);

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        stack,
        if (currentLabel != null && showLabel) ...[
          const SizedBox(height: 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final text = DefaultTextStyle(
                style:
                    (Theme.of(context).textTheme.labelSmall ??
                            const TextStyle())
                        .copyWith(color: effectiveColor),
                child: labelChild,
              );
              return constraints.hasBoundedWidth
                  ? SizedBox(width: double.infinity, child: text)
                  : text;
            },
          ),
        ],
      ],
    );

    Widget child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 48, minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          // heightFactor keeps the item content-tall when the bar hands it
          // loose height up to the full screen.
          child: Center(heightFactor: 1, child: column),
        ),
      ),
    );

    if (tooltip != null) {
      child = Tooltip(
        message: tooltip!,
        excludeFromSemantics: true,
        child: child,
      );
    }

    if (accessibleLabel != null) {
      child = ExcludeSemantics(child: child);
    }

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: accessibleLabel,
      onTap: accessibleLabel != null ? onTap : null,
      child: child,
    );
  }
}
