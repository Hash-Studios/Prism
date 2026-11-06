import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/theme.dart' show prismSoftInk;
import 'package:flutter/material.dart';

/// One tappable action in [WallpaperActionBar]. [child] is the button, [label] its tooltip.
class WallpaperBarAction {
  const WallpaperBarAction({required this.label, required this.child, this.caption});

  final String label;
  final Widget child;

  /// The short word under an icon action. Null shows [label].
  final String? caption;
}

/// The row under the wallpaper card: plain icon [actions] at the start, then the [secondary] icons and the labelled
/// [primary] action at the end. Each icon action has its caption under the icon. It paints no surface of its own.
class WallpaperActionBar extends StatelessWidget {
  const WallpaperActionBar({required this.primary, required this.actions, this.secondary = const [], super.key});

  /// Height of the row, including the space above the buttons and the captions under them.
  static const double height = 68;

  /// How far the caption hangs below the button. The rest of it sits in the button's own bottom padding, so a tap on
  /// the caption still reaches the button.
  static const double _captionDrop = 6;

  final WallpaperBarAction primary;
  final List<WallpaperBarAction> actions;

  /// Icon actions that belong with [primary], placed just before it.
  final List<WallpaperBarAction> secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
        child: LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: FlatMenuButtons(
                iconSize: 24,
                padding: const EdgeInsets.all(13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[for (final WallpaperBarAction action in actions) _captioned(context, action)],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final WallpaperBarAction action in secondary) _captioned(context, action),
                        Tooltip(message: primary.label, triggerMode: TooltipTriggerMode.manual, child: primary.child),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [action] with its caption under the icon. The button already gives its label to screen readers.
  Widget _captioned(BuildContext context, WallpaperBarAction action) {
    return Tooltip(
      message: action.label,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: _captionDrop),
            child: action.child,
          ),
          Positioned(
            left: -PrismSpace.xs,
            right: -PrismSpace.xs,
            bottom: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.2,
                  child: Text(
                    action.caption ?? action.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: PrismTextStyles.caption(context).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: prismSoftInk(Theme.of(context)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
