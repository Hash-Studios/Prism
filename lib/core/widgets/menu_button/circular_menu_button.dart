import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

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
    this.selected,
    this.caption,
    this.onImage = false,
  });

  /// Screen reader label.
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool isLoading;

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
    final Color bg = onImage ? Colors.black.withValues(alpha: 0.38) : cs.onSurface.withValues(alpha: 0.08);
    final Widget circle = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Stack(
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
        ),
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
}
