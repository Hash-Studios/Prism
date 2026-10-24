import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// Makes every [CircularMenuButton] below it draw a bare icon button: no fill and no shadow. This is the look of the
/// glass action bar on the wallpaper detail screen, and it keeps the metrics of the current app: a 20 point icon in the
/// theme ink with [CircularMenuButton.padding] around it. A row can set its own [iconSize] and [padding]; a button's
/// own padding still wins.
class FlatMenuButtons extends InheritedWidget {
  const FlatMenuButtons({super.key, this.iconSize = 20, this.padding = const EdgeInsets.all(17), required super.child});

  final double iconSize;

  /// Space around each icon whose button sets no padding of its own.
  final EdgeInsets padding;

  static FlatMenuButtons? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlatMenuButtons>();

  static bool of(BuildContext context) => maybeOf(context) != null;

  @override
  bool updateShouldNotify(FlatMenuButtons oldWidget) => iconSize != oldWidget.iconSize || padding != oldWidget.padding;
}

/// Shared skeleton for the round action buttons of the wallpaper detail screen: a 48 point neutral circle around
/// [child], a spinner ring while [isLoading], and press feedback. The icon in [child] takes its colour and size from
/// the button. With a [caption] the label is shown under the circle.
class CircularMenuButton extends StatelessWidget {
  const CircularMenuButton({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    required this.isLoading,
    this.padding,
    this.selected,
    this.caption,
    this.onImage = false,
  });

  /// Screen reader label.
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool isLoading;

  /// Space around [child] in the bare look. Null takes the padding of the enclosing [FlatMenuButtons].
  final EdgeInsets? padding;

  /// For toggle actions such as Favourite, so screen readers announce the current state.
  final bool? selected;

  /// Short visible label under the circle.
  final String? caption;

  /// For a button that sits on a wallpaper: a dark translucent circle and a white icon on every theme.
  final bool onImage;

  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = onImage ? Colors.white : cs.onSurface;
    final FlatMenuButtons? flat = FlatMenuButtons.maybeOf(context);
    if (flat != null) return _flatButton(context, flat);
    final Color bg = onImage ? Colors.black.withValues(alpha: 0.38) : cs.onSurface.withValues(alpha: 0.08);
    final Widget face = Stack(
      alignment: Alignment.center,
      children: <Widget>[
        IconTheme(
          data: IconThemeData(color: fg, size: 22),
          child: Center(child: child),
        ),
        IgnorePointer(
          child: AnimatedSwitcher(
            duration: context.motion(PrismDurations.fast),
            child: isLoading
                ? Padding(
                    key: const ValueKey<bool>(true),
                    padding: const EdgeInsets.all(PrismSpace.xxs),
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : const SizedBox.shrink(key: ValueKey<bool>(false)),
          ),
        ),
      ],
    );
    final Widget circle = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: face,
      ),
    );
    final Widget content = caption == null
        ? circle
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              circle,
              const SizedBox(height: PrismSpace.xxs + 2),
              ExcludeSemantics(
                child: Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.caption(context),
                ),
              ),
            ],
          );
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: PressScale(
        child: onTap == null
            ? content
            : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content),
      ),
    );
  }

  /// The bare look of the glass action bar, as on the current app.
  Widget _flatButton(BuildContext context, FlatMenuButtons flat) {
    final Widget button = Stack(
      children: <Widget>[
        Padding(
          padding: padding ?? flat.padding,
          child: IconTheme(
            data: IconThemeData(color: Theme.of(context).colorScheme.secondary, size: flat.iconSize),
            child: child,
          ),
        ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: context.motion(const Duration(milliseconds: 120)),
            child: isLoading
                ? const CircularProgressIndicator(key: ValueKey<bool>(true), strokeWidth: 2)
                : const SizedBox.shrink(key: ValueKey<bool>(false)),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: onTap == null
          ? button
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: PressScale(child: button),
            ),
    );
  }
}
